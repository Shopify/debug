# frozen_string_literal: true

require_relative '../support/protocol_test_case'

module DEBUGGER__
  class EvalTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| b = 3
      3| c = 1
      4| d = 4
      5| e = 5
      6| f = 6
    RUBY

    def test_eval_evaluates_arithmetic_expressions
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 5
        req_continue
        assert_repl_result({value: '2', type: 'Integer'}, 'a')
        assert_repl_result({value: '4', type: 'Integer'}, 'd')
        assert_repl_result({value: '3', type: 'Integer'}, '1+2')
        req_terminate_debuggee
      end
    end

    def test_eval_workaround
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue
        send_evaluate_request(",b 5")
        req_continue
        assert_line_num 5
        req_terminate_debuggee
      end
    end

    def send_evaluate_request(expression)
      res = send_dap_request 'stackTrace',
                    threadId: 1,
                    startFrame: 0,
                    levels: 20
      f_id = res.dig(:body, :stackFrames, 0, :id)
      send_dap_request 'evaluate',
                    expression: expression,
                    frameId: f_id,
                    context: "repl"
      # the preset command we add in the previous request needs to be triggered
      # by another session action (request in this case).
      # in VS Code this naturally happens because it'll send a Scope request follow the
      # evaluate request, but in our test we need to do it manually.
      send_dap_request 'scopes', frameId: f_id
    end
  end
end
