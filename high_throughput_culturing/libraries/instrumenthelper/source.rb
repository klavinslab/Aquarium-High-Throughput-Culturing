# Common instrument class methods. Try to find common methods in instrument classes.
module InstrumentHelper
  attr_accessor :measurement_type, :experimental_item, :measurement_item, :transfer_required, :measurement_data
  def setup_experimental_measurement(experimental_item:, output_fv:)
    @experimental_item = experimental_item
    transfer?(output_fv: output_fv)
  end
  
  def transfer?(output_fv:)
    if transfer_needed
      output_fv.make
      @measurement_item = output_fv.item
    else
      @measurement_item = experimental_item
    end
  end
  
  def transfer_needed
    @transfer_required = !valid_container?
  end
  
  def self.intrument_type?
    self.class.to_s
  end
end
