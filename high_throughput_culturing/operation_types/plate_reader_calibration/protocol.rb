# By: Eriberto Lopez 03/14/19
# elopez3@uw.edu

needs "High Throughput Culturing/PlateReaderHelper"
class Protocol
  include PlateReaderHelper
  
  # DEF
  OD_CALIBRATION = "Optical Particles"
  FLOUR_CALIBRATION = "Fluorescent Salt"
  OUTPUT = "Calibration Plate"
  
  # Constants
  MEASUREMENT_TYPE = 'Calibration'
  
  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  def main # Typically one calibration op per Plan
    pr = intro
    new_mtype = true
    pr.measurement_type = MEASUREMENT_TYPE
    operations.group_by {|op| op.input(FLOUR_CALIBRATION).item }.each do |flour_item, ops|
      ops.group_by {|op| op.input(OD_CALIBRATION).item }.each do |optical_item, ops|
        # Based on whether an unexpired calibration plate is made, prepare a calibration plate for measurement
        new_mtype = prep_calibration_plate(pr, ops, OUTPUT, flour_item, optical_item)
        take_measurement_and_upload_data(pr: pr)
        process_and_associate_data(pr: pr,  ops: ops) 
        change_item_location(item: pr.measurement_item, location: "4#{DEGREES_C} Fridge")
      end
    end
    cleaning_up(pr: pr)
  end # Main
end # Protocol




