# Flow Cytometry Calibration

To compare different experiments against each other we must have a way to compare the fluorescence intensities across different flow cytometers.
To achieve this we will be using small beads that fluoresce multiple colors.

    1. Setup flow cytometer workspace and measure bead sample.
    
    2. Take chosen beads and dilute, if necessary.
    
    3. Upload .fcs file to Aquarium.
### Inputs


- **Optical Particles** [OP]  
  - <a href='#' onclick='easy_select("Sample Types", "Beads")'>Beads</a> / <a href='#' onclick='easy_select("Containers", "Bead droplet dispenser")'>Bead droplet dispenser</a>



### Outputs


- **Diluted Beads** [OP]  
  - <a href='#' onclick='easy_select("Sample Types", "Beads")'>Beads</a> / <a href='#' onclick='easy_select("Containers", "Diluted beads")'>Diluted beads</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez
# elopez3@uw.edu
# 08/13/19

needs "High Throughput Culturing/FlowCytometryHelper"
needs "High Throughput Culturing/FlowCytometryCalibration"
needs "High Throughput Culturing/HighThroughputHelper"
needs "Standard Libs/Debug"

class Protocol
    include Debug
  #include FlowCytometryCalibration, HighThroughputHelper 
  #include FlowCytometryHelper
  
  # DEF
  INPUT  = "Optical Particles"
  OUTPUT = "Diluted Beads"
  
  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
    
  def intro
    flow_cytometer = FlowCytometer.new()
    get_flow_cytometer_software(flow_cytometer: flow_cytometer)
    show do
      title "Calibrating the Flow Cytometer"
      separator
      note "To compare different experiments against each other we must have a way to compare the fluorescence intensities across different flow cytometers."
      note "To achieve this we will be using small beads that fluoresce multiple colors."
      note "<b>1.</b> Setup flow cytometer workspace and measure bead sample."
      note "<b>2.</b> Take chosen beads and dilute, if necessary."
      note "<b>3.</b> Upload .fcs file to Aquarium."
    end
    return flow_cytometer
  end
  
  def main
    fc = intro
    operations.group_by {|op| op.input(INPUT).item }.each do |bead_item, ops|
      setup_calibration_measurement(flow_cytometer: fc, bead_item: bead_item)
      setup_instrument_calibration(instrument=fc)
      empty_containers = []; new_materials = []; take_items = [fc.experimental_item]
      (empty_containers.push(fc.measurement_item); new_materials.push('P1000 Pipette', 'Molecular Grade H2O', '1.5mL Tube')) unless (fc.experimental_item.id == fc.measurement_item.id)
      gather_materials(empty_containers: empty_containers, transfer_required: fc.transfer_required, new_materials: new_materials, take_items: take_items)
      prepare_calibration_beads(flow_cytometer: fc)
      take_calibration_and_upload_data(instrument: fc)
      process_and_associate_calibration(instrument: fc, ops: ops)
      fc.measurement_item.location = 'R4 Fridge'
    end
    release_arr = Protocol.materials_list.flatten.reject {|m| m.is_a? String }.uniq
    cleaning_up(release_arr)
  end # Main

end # Protocol

```
