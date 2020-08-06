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
