# PR Calibration

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.
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

needs "Plate Reader/PlateReaderHelper"
class Protocol
  include PlateReaderHelper
  
  # DEF
  OD_CALIBRATION = "Optical Particles"
  FLOUR_CALIBRATION = "Fluorescent Salt"
  OUTPUT = "Calibration Plate"
  
  # Access class variables via Protocol.your_class_method
  @@materials_list = []
  def self.materials_list; @@materials_list; end
  
  def main # Typically one calibration op per Plan
    pr = intro
    new_mtype = true
    pr.measurement_type = 'Calibration'
    operations.group_by {|op| op.input(FLOUR_CALIBRATION).item}.each do |flour_item, ops|
      ops.group_by {|op| op.input(OD_CALIBRATION).item}.each do |optical_item, ops|
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
