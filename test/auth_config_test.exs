defmodule MessagesTest do
  use ExUnit.Case
  doctest Neo4j.Protocol.Messages

  alias Neo4j.Protocol.Messages

  describe "message creation" do
    test "creates HELLO message" do
      auth = %{"scheme" => "basic", "principal" => "neo4j", "credentials" => "password"}
      hello_msg = Messages.hello("neo4j_ex/0.1.0", auth)

      assert {:struct, 0x01, [extra]} = hello_msg
      assert extra["user_agent"] == "neo4j_ex/0.1.0"
      assert extra["scheme"] == "basic"
      assert extra["principal"] == "neo4j"
      assert extra["credentials"] == "password"
    end

    test "creates HELLO message with bolt_agent" do
      auth = %{"scheme" => "basic", "principal" => "neo4j", "credentials" => "password"}
      bolt_agent = %{"product" => "neo4j_ex/0.1.0", "language" => "Elixir"}
      hello_msg = Messages.hello("neo4j_ex/0.1.0", auth, bolt_agent: bolt_agent)

      assert {:struct, 0x01, [extra]} = hello_msg
      assert extra["bolt_agent"] == bolt_agent
    end

    test "creates GOODBYE message" do
      goodbye_msg = Messages.goodbye()
      assert goodbye_msg == {:struct, 0x02, []}
    end

    test "creates RUN message" do
      run_msg = Messages.run("RETURN 1", %{"param" => "value"}, %{"mode" => "r"})
      assert run_msg == {:struct, 0x10, ["RETURN 1", %{"param" => "value"}, %{"mode" => "r"}]}
    end

    test "creates PULL message" do
      pull_msg = Messages.pull(%{"n" => -1})
      assert pull_msg == {:struct, 0x3F, [%{"n" => -1}]}
    end

    test "creates transaction messages" do
      begin_msg = Messages.begin_tx(%{"mode" => "w"})
      assert begin_msg == {:struct, 0x11, [%{"mode" => "w"}]}

      commit_msg = Messages.commit()
      assert commit_msg == {:struct, 0x12, []}

      rollback_msg = Messages.rollback()
      assert rollback_msg == {:struct, 0x13, []}
    end
  end

  describe "response parsing" do
    test "parses SUCCESS response" do
      response = {:struct, 0x70, [%{"server" => "Neo4j/5.0.0"}]}
      assert Messages.parse_response(response) == {:success, %{"server" => "Neo4j/5.0.0"}}
    end

    test "parses FAILURE response" do
      response = {:struct, 0x7F, [%{"code" => "Neo.ClientError.Security.Unauthorized", "message" => "Auth failed"}]}
      assert Messages.parse_response(response) == {:failure, %{"code" => "Neo.ClientError.Security.Unauthorized", "message" => "Auth failed"}}
    end

    test "parses RECORD response" do
      response = {:struct, 0x71, [[1, "hello"]]}
      assert Messages.parse_response(response) == {:record, [1, "hello"]}
    end

    test "parses IGNORED response" do
      response = {:struct, 0x7E, []}
      assert Messages.parse_response(response) == {:ignored, %{}}
    end

    test "handles unknown response" do
      response = {:struct, 0xFF, ["unknown"]}
      assert Messages.parse_response(response) == {:unknown, 0xFF, ["unknown"]}
    end
  end

  describe "message encoding and chunking" do
    test "encodes and chunks messages" do
      hello_msg = Messages.hello("test", %{})
      encoded = Messages.encode_message(hello_msg)

      # Should end with 0x0000 (end of message marker)
      assert String.ends_with?(encoded, <<0x00, 0x00>>)

      # Should start with chunk size
      <<chunk_size::16, _rest::binary>> = encoded
      assert chunk_size > 0
    end

    test "decodes chunked messages" do
      hello_msg = Messages.hello("test", %{})
      encoded = Messages.encode_message(hello_msg)

      {:ok, decoded, <<>>} = Messages.decode_message(encoded)
      assert decoded == hello_msg
    end

    test "handles incomplete messages" do
      # Incomplete chunk header
      assert Messages.decode_message(<<0x00>>) == {:incomplete}

      # Incomplete chunk data
      assert Messages.decode_message(<<0x00, 0x10, "incomplete">>) == {:incomplete}
    end
  end

  describe "utility functions" do
    test "returns signature names" do
      assert Messages.signature_name(0x01) == "HELLO"
      assert Messages.signature_name(0x02) == "GOODBYE"
      assert Messages.signature_name(0x10) == "RUN"
      assert Messages.signature_name(0x3F) == "PULL"
      assert Messages.signature_name(0x70) == "SUCCESS"
      assert Messages.signature_name(0x7F) == "FAILURE"
      assert Messages.signature_name(0xFF) == "UNKNOWN(0xFF)"
    end

    test "identifies summary messages" do
      success_msg = {:struct, 0x70, [%{}]}
      failure_msg = {:struct, 0x7F, [%{}]}
      record_msg = {:struct, 0x71, [[]]}

      assert Messages.summary_message?(success_msg) == true
      assert Messages.summary_message?(failure_msg) == true
      assert Messages.summary_message?(record_msg) == false
    end
  end
end
