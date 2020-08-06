# By: Eriberto Lopez 03/14/19
# elopez3@uw.edu
needs "High Throughput Culturing/PlateReaderHelper"

class Protocol
  include PlateReaderHelper
  # DEF
  INPUT            = "Culturing Plate"
  OUTPUT           = "Plate Reader Plate"
  MEDIA            = 'Media'
  DILUTION         = "Dilution"
  KEEP_OUT_PLT     = "Keep Output Plate?"
  MEASUREMENT_TYPE = 'Type of Measurement(s)'
  WHEN_TO_MEASURE  = "When to Measure? (24hr)"
  
  # Access class variables via Protocol.your_class_method
  @materials_list = []
  def self.materials_list; @materials_list; end
  
  # TODO: Get time series measurements online
  def main
    pr = intro
    operations.group_by {|op| op.input(MEASUREMENT_TYPE).val.to_sym }.each do |measurement_type, ops|
      new_mtype = true
      pr.measurement_type = measurement_type
      ops.each do |op|
        op = Operation.find(179078) if debug
        # Use class PlateReader to setup the experimental measurement
        pr.setup_experimental_measurement(experimental_item: op.input(INPUT).item, output_fv: op.output(OUTPUT))
        new_mtype = setup_plate_reader_software_env(pr: pr, new_mtype: new_mtype)
        # Gather materials and items
        media_item = get_media_bottle(op)
        take_items = [pr.experimental_item, media_item].flatten.reject {|i| i.nil?}
        gather_materials(empty_containers: [pr.measurement_item], transfer_required: pr.transfer_required, new_materials: ['P1000 Multichannel'], take_items: take_items )
        # Prepare plate for plate reader
        dilution_factor = get_dilution_factor(op: op, fv_str: DILUTION)
        media_vol_ul, culture_vol_ul = get_culture_and_media_vols(dilution_factor: dilution_factor, measurement_item: pr.measurement_item)
        (pr.transfer_required) ? tech_prefill_and_transfer(pr: pr, media_sample: media_item.sample, media_vol_ul: media_vol_ul, culture_vol_ul: culture_vol_ul) : op.pass(INPUT, OUTPUT)
        tech_add_blanks(pr: pr, blanking_sample: media_item.sample, culture_vol_ul: culture_vol_ul, media_vol_ul: media_vol_ul) # Cannot handle a plate without blanks, esp in processing of upload
        take_measurement_and_upload_data(pr: pr)
        process_and_associate_data(pr: pr,  ops: [op], blanking_sample: media_item.sample, dilution_factor: dilution_factor)
        # Keep new measurement plate that was created?
        (pr.transfer_required) ? (keep_transfer_plate(pr: pr, user_val: get_parameter(op: op, fv_str: KEEP_OUT_PLT).to_s.upcase)) : (pr.measurement_item.location = 'Bench')
      end
    end 
    cleaning_up(pr: pr)
  end # Main
end # Protocol
