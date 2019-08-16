# Plate Reader Calibration

This protocol will instruct you on how to take measurements to calibrate and compare measurements on the plate_reader.type Plate Reader.
This protocol will also guide you through preparing the calibration plate input item or gathering an unexpired one.

    1. Setup plate_reader.type Plate Reader Software workspace.
    
    2. Check to see if input item is a plate_reader.valid_containers if not, transfer samples to a valid container.
    
    3. Prepare measurement item with blanks.
    
    4. Take measurement, export data, & upload.
### Inputs


- **Optical Particles** [OP]  
  - <a href='#' onclick='easy_select("Sample Types", "Plate Reader Calibration Solution")'>Plate Reader Calibration Solution</a> / <a href='#' onclick='easy_select("Containers", "1X LUDOX Aliquot")'>1X LUDOX Aliquot</a>

- **Fluorescent Salt** [FS]  
  - <a href='#' onclick='easy_select("Sample Types", "Plate Reader Calibration Solution")'>Plate Reader Calibration Solution</a> / <a href='#' onclick='easy_select("Containers", "1mM Fluorescein Stock")'>1mM Fluorescein Stock</a>



### Outputs


- **Calibration Plate** [PR]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
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





```
