# Flow Cytometry Measurement

This protocol will instruct you on how to take measurements on the #{flow_cytometer.type} Flow Cytometer.
A flow cytomter uses lasers to phenotypically characterize a microbial culture.
This per cell measurement quantifies a cell's size, shape, and color. Making it a useful tool to analyze & distiguish cellular populations from each other.
In this protocol, you will prepare the instrument workspace and characterize your genetically modified organism.

    1. Setup flow_cytometer.type Flow Cytomter Software workspace.
    
    2. Check to see if input item is a flow_cytometer.valid_containers if not, transfer samples to a valid container.
    
    3. Load plate.
    
    4. Take measurement, export data, & upload.
### Inputs


- **Experimental Plate** [P]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "Eppendorf 96 Deepwell Plate")'>Eppendorf 96 Deepwell Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 U-bottom Well Plate")'>96 U-bottom Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Deep Well Plate")'>24 Deep Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Parameters

- **Calibration Required?** [Yes,No]
- **Keep Output Plate?** [Yes,No]
- **When to Measure? (24hr)** 

### Outputs


- **Measurement Plate** [P]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 U-bottom Well Plate")'>96 U-bottom Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Unit Disorganized Collection")'>24 Unit Disorganized Collection</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  if _op.input('require calibration?').value.downcase == 'yes'
    calibration_operation_type = OperationType.find_by_name("Flow Cytometry Calibration")
    calibration_op = _op.plan.operations.find { |op| op.operation_type_id == calibration_operation_type.id}
    if calibration_op.nil?
      _op.associate('Waiting for Calibration','In order to use Cytometer, `Cytometer Bead Calibration` must be run in the same plan')
      return false
    elsif calibration_op.status != 'done'
      _op.associate("Waiting for Calibration","Flow Cytometry cannot begin until Cytometer Calibration completes.")
      return false
    else
      _op.get_association('Waiting for Calibration').delete if _op.get_association('Waiting for Calibration')
      return true
    end
  else
    return true
  end
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez
# elopez3@uw.edu
# 08/07/19

needs "High Throughput Culturing/FlowCytometryHelper"
needs "High Throughput Culturing/HighThroughputHelper"
needs "Standard Libs/Debug"

class Protocol
  include Debug
  include FlowCytometryHelper
  include HighThroughputHelper

  # DEF
  INPUT            = 'Experimental Plate'
  OUTPUT           = 'Measurement Plate'
  KEEP_OUT_PLT     = 'Keep Output Plate?'
  WHEN_TO_MEASURE  = 'When to Measure? (24hr)'

  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end

  def main
    fc = intro
    operations.each do |op|
      op = Operation.find(219_542) if debug

      fc.setup_experimental_measurement(experimental_item: op.input(INPUT).item,
                                        output_fv: op.output(OUTPUT))

      setup_instrument_software(instrument=fc, op)

      empty_containers = []
      new_materials = []
      take_items = [fc.experimental_item]

      unless !fc.transfer_required
        empty_containers.push(fc.measurement_item)
        new_materials.push('P1000 Multichannel', 'Area Seal')
      end

      gather_materials(empty_containers: empty_containers,
                       transfer_required: fc.transfer_required,
                       new_materials: new_materials,
                       take_items: take_items)

      (fc.transfer_required) ? tech_transfer_to_valid_container(instrument: fc,
                                                                output_fieldValue: op.output(OUTPUT)) : op.pass(INPUT, OUTPUT)
      take_measurement_and_upload_data(instrument: fc)
      process_and_associate_data(instrument: fc, op: op)

      # Keep new measurement plate that was created?
      keep_transfer_plate(instrument: fc, 
                          user_val: get_parameter(op: op, fv_str: KEEP_OUT_PLT).to_s.upcase)
    end
    show do
      Protocol.materials_list.each do |mat|
        note "material #{mat}"
      end
    end
    release_arr = Protocol.materials_list.flatten.reject { |m| m.is_a? String }.uniq
    cleaning_up(release_arr)
  end # Main
end # Protocol

```
