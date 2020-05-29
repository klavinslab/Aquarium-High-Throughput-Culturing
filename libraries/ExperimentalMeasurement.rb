# By: Eriberto Lopez
# elopez3@uw.edu
# 03/13/19

needs "Plate Reader/PlateReaderConstants" 
needs "Standard Libs/AssociationManagement"

module ExperimentalMeasurement
  attr_accessor :measurement_type, :experimental_item, :measurement_item, :transfer_required, :measurement_data
  def setup_experimental_measurement(experimental_item:, output_fv:)
    @experimental_item = experimental_item
    transfer?(output_fv: output_fv)
  end
  
  def transfer?(output_fv:)
    if transfer_needed
      output_fv.make
      measurement_item = output_fv.item
    else
      measurement_item = experimental_item
    end
    @measurement_item = measurement_item
  end
  
  def transfer_needed
    @transfer_required = !valid_container?
  end
  
end

# Can this be used to represent composite wells?
class Struct 
  def self.hash_initialized *params
    klass = Class.new(self.new(*params))

    klass.class_eval do
      define_method(:initialize) do |h|
        super(*h.values_at(*params))
      end
    end
    klass
  end
end

# module HasProperties
#   attr_accessor :props

#   def self.included base
#     base.extend self
#   end
  
#   def has_properties(*args)
#     @props = args
#     instance_eval { attr_accessor *args }
#   end
  
#   def initialize(args={})
#     args.each {|k,v|
#       instance_variable_set "@#{k}", v if self.class.props.member?(k)
#     } if args.is_a? Hash
#   end
# end