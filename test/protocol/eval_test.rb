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

    def test_eval_executes_commands
      run_protocol_scenario PROGRAM, cdp: false do
        req_add_breakpoint 3
        req_continue
        assert_repl_result({value: '(rdbg:command) b 5 ;; b 6', type: nil}, ",b 5 ;; b 6")
        req_continue
        assert_line_num 5
        req_continue
        assert_line_num 6
        req_terminate_debuggee
      end
    end
  end

  class EvaluateOnSomeFramesTest < ProtocolTestCase
    PROGRAM = <<~RUBY
      1| a = 2
      2| def foo
      3|   a = 4
      4| end
      5| foo
    RUBY

    def test_eval_evaluates_arithmetic_expressions
      run_protocol_scenario PROGRAM do
        req_add_breakpoint 4
        req_continue
        assert_repl_result({value: '4', type: 'Integer'}, 'a', frame_idx: 0)
        assert_repl_result({value: '2', type: 'Integer'}, 'a', frame_idx: 1)
        req_terminate_debuggee
      end
    end
  end

  class EvaluateThreadTest < ProtocolTestCase
    def test_eval_doesnt_deadlock
      program = <<~RUBY
        1| th0 = Thread.new{sleep}
        2| m = Mutex.new; q = Queue.new
        3| th1 = Thread.new do
        4|   m.lock; q << true
        5|   sleep 1
        6|   m.unlock
        7| end
        8| q.pop # wait for locking
        9| p :ok
      RUBY

      run_protocol_scenario program, cdp: false do
        req_add_breakpoint 9
        req_continue
        assert_repl_result({value: 'false', type: 'FalseClass'}, 'm.lock.nil?', frame_idx: 0)
        req_continue
      end
    end

    def test_eval_stops_threads_after_finished
      program = <<~RUBY
     1| count = 0
     2| m = Thread::Mutex.new
     3| m.lock
     4|
     5| th0 = Thread.new do
     6|   loop do
     7|     m.synchronize do
     8|       count += 1
     9|       p :th0
    10|     end
    11|   end
    12| end
    13|
    14| __LINE__
      RUBY

      run_protocol_scenario program, cdp: false do
        req_add_breakpoint 14
        req_continue
        assert_repl_result({value: 'false', type: 'FalseClass'}, 'm.unlock.nil?', frame_idx: 0)
        locals = gather_variables
        count_var_value_1 = locals.find{|v| v[:name] == 'count'}[:value]
        locals = gather_variables
        count_var_value_2 = locals.find{|v| v[:name] == 'count'}[:value]
        # if the thread is stopped, the value of count will not be changed.
        assert_equal(count_var_value_1, count_var_value_2)

        req_continue
      end
    end
  end
end
