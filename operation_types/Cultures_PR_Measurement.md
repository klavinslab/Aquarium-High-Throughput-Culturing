# Cultures PR Measurement

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.
### Inputs


- **Cultures** [PR]  
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast Overnight Suspension")'>Yeast Overnight Suspension</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast 250ml culture")'>Yeast 250ml culture</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast 100ml culture")'>Yeast 100ml culture</a>
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "Yeast 50ml culture")'>Yeast 50ml culture</a>

- **Media** [M]  
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "200 mL Liquid")'>200 mL Liquid</a>
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "400 mL Liquid")'>400 mL Liquid</a>
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "800 mL Liquid")'>800 mL Liquid</a>

### Parameters

- **Type of Measurement(s)** [Optical Density,Green Fluorescence,Optical Density & Green Fluorescence]
- **Dilution** [None,0.5X,0.2X,0.1X, 0.01X,0.001X]
- **Batch?** [Yes]
- **When to Measure? (24hr)** 
- **Keep Output Plate?** [Yes,No]

### Outputs


- **Plate Reader Plate** [PR]  Part of collection
  - <a href='#' onclick='easy_select("Sample Types", "Yeast Strain")'>Yeast Strain</a> / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>

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
  INPUT            = "Cultures"
  OUTPUT           = "Plate Reader Plate"
  BATCH            = "Batch?"
  MEDIA            = 'Media'
  DILUTION         = "Dilution"
  KEEP_OUT_PLT     = "Keep Output Plate?"
  MEASUREMENT_TYPE = 'Type of Measurement(s)'
  WHEN_TO_MEASURE  = "When to Measure? (24hr)"
  # Access class variables via Protocol.your_class_method
  @@materials_list = []
  def self.materials_list; @@materials_list; end
  
  # TODO: Get time series measurements online
  def main
    pr = intro
    operations.group_by {|op| get_parameter(op: op, fv_str: MEASUREMENT_TYPE).to_sym}.each do |measurement_type, ops|
      new_mtype = true
      pr.measurement_type = measurement_type
      ops.group_by {|op| op.input(INPUT).sample.sample_type}.each do |st, ops|
        ops.group_by {|op| op.input(MEDIA).item}.each do |media_item, ops|
          ops.group_by {|op| get_uninitialized_output_object_type(op)}.each do |out_ot, ops|
            ops.make
            ops.group_by {|op| op.output(OUTPUT).collection}.each do |out_collection, ops|
              pr.setup_experimental_measurement(experimental_item: out_collection, output_fv: nil)
              new_mtype = setup_plate_reader_software_env(pr: pr, new_mtype: new_mtype)
              # Gather materials and items
              take_items = [media_item].concat([pr.experimental_item].flatten)
              gather_materials(empty_containers: [pr.measurement_item], transfer_required: pr.transfer_required, new_materials: ['P1000 Multichannel'], take_items: take_items)
              # Prep plate
              display_hash = get_transfer_display_hash(ops: ops, input_str: INPUT, output_str: OUTPUT, dilution_str: DILUTION)
              prefill_plate_w_media(collection: pr.measurement_item, media_sample: media_item.sample, media_vol_ul: nil, display_hash: display_hash) # media_vol_ul must be > 0 to run show block
              take ops.map {|op| op.input(INPUT).item}, interactive: true
              tech_transfer_cultures(collection: pr.measurement_item, display_hash: display_hash)
              tech_add_blanks(pr: pr, blanking_sample: media_item.sample, culture_vol_ul: 0.0, media_vol_ul: 300.0) # Cannot handle a plate without blanks, esp in processing of upload
              
              take_measurement_and_upload_data(pr: pr)
              
              dilution_factor_arr = ops.map {|op| get_dilution_factor(op: op, fv_str: DILUTION)}
              
              process_and_associate_data(pr: pr,  ops: ops, blanking_sample: media_item.sample, dilution_factor: dilution_factor_arr)
            end
            keep_p_arr = ops.select {|op| op.input(KEEP_OUT_PLT).val.to_s.downcase == 'yes'}
            (keep_p_arr.empty?) ? pr.measurement_item.mark_as_deleted : pr.measurement_item.location = 'Bench'
          end
        end
      end
    end
    cleaning_up(pr: pr)
  end # main
end # Protocol
```
