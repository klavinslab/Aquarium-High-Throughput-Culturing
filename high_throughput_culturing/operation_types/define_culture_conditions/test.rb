class ProtocolTest < ProtocolTestBase
  MEDIA = "Media"
  CONTROL = "Control Tag as { tag, type }"
  INDUCERS = "Inducer(s) as { name: { final concentration: { qty:, units: } } }"
  ANTIBIOTICS = "Antibiotic(s) as { name: { final concentration: { qty:, units: } } }"
  REPLICATES = "Replicates"
  TEMPERATURE = "Temperature (C)"




  def setup

      # add_random_operations(1) # defines three random operations
      add_operation
        .with_input(MEDIA, Sample.find(	11767))
        .with_input(CONTROL, {})
        .with_input(INDUCERS, { 'IPTG': { final_concentration: { 'qty': 10  , 'units': 'uM' } } })
        .with_input(ANTIBIOTICS, { 'Kanamyacin': { final_concentration: { 'qty': 10  , 'units': 'nM' } } })
        .with_input(REPLICATES, 3)
        .with_input(TEMPERATURE, 30)

        



      # add_operation            # adds a custom made operation
      #   .with_input("Primer", Sample.find(3))
      #   .with_property("x", 123)
      #   .with_output("Primer", Sample.find(3))     

  end

  def analyze
      log "Hello from Nemo LIVE!"
      @operations.each do |op|
        log "#{op.id}"
      end

      # log "#{@backtrace}"
      assert_equal @backtrace.last[:operation], "complete"
      
  end

end