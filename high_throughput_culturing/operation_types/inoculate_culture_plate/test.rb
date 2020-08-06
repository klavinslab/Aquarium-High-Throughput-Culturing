class ProtocolTest < ProtocolTestBase

  def setup

      add_random_operations(3) # defines three random operations

      add_operation            # adds a custom made operation
        .with_input("Primer", Sample.find(3))
        .with_property("x", 123)
        .with_output("Primer", Sample.find(3))

  end

  def analyze
      log "Hello from Nemo"
      assert_equal @backtrace.last[:operation], "complete"
  end

end