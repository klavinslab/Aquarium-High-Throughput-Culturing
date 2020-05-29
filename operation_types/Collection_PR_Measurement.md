# Collection PR Measurement

Documentation here. Start with a paragraph, not a heading or title, as in most views, the title will be supplied by the view.
### Inputs


- **Culture Plate** [PR]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24-Well TC Dish")'>24-Well TC Dish</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24 Deep Well Plate")'>24 Deep Well Plate</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 U-bottom Well Plate")'>96 U-bottom Well Plate</a>

- **Media** [M]  
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "200 mL Liquid")'>200 mL Liquid</a>
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "400 mL Liquid")'>400 mL Liquid</a>
  - <a href='#' onclick='easy_select("Sample Types", "Media")'>Media</a> / <a href='#' onclick='easy_select("Containers", "800 mL Liquid")'>800 mL Liquid</a>

### Parameters

- **Type of Measurement(s)** [Optical Density,Green Fluorescence,Optical Density & Green Fluorescence,]
- **Dilution** [None,0.5X, 0.2X,0.1X, 0.01X,0.001X]
- **Keep Output Plate?** [Yes,No]
- **When to Measure? (24hr)** 

### Outputs


- **Plate Reader Plate** [PR]  
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "96 Well Flat Bottom (black)")'>96 Well Flat Bottom (black)</a>
  - NO SAMPLE TYPE / <a href='#' onclick='easy_select("Containers", "24-Well TC Dish")'>24-Well TC Dish</a>

### Precondition <a href='#' id='precondition'>[hide]</a>
```ruby
def precondition(_op)
  true
end
```

### Protocol Code <a href='#' id='protocol'>[hide]</a>
```ruby
# By: Eriberto Lopez 03/13/19
# elopez3@uw.edu

# needs "Plate Reader/ExperimentalMeasurement"
needs "Plate Reader/PlateReaderHelper"

class Protocol
  include PlateReaderHelper
  
  # DEF
  INPUT            = "Culture Plate"
  OUTPUT           = "Plate Reader Plate"
  MEDIA            = 'Media'
  DILUTION         = "Dilution"
  KEEP_OUT_PLT     = "Keep Output Plate?"
  MEASUREMENT_TYPE = 'Type of Measurement(s)'
  WHEN_TO_MEASURE  = "When to Measure? (24hr)"
  
  # Access class variables via Protocol.your_class_method
  @@materials_list = []
  def self.materials_list; @@materials_list; end
  
  # TODO: Get time series measurements online
  def intro
    plate_reader = PlateReader.new
    show do
      title "Plate Reader Measurements"
      separator
      note "This protocol will instruct you on how to take measurements on the #{plate_reader.type} Plate Reader."
      note "Optical Density is a quick and easy way to measure the growth rate of your cultures."
      note "Green Fluorescence helps researchers assess a response to a biological condition <i>in vivo</i>."
      note "<b>1.</b> Setup #{plate_reader.type} Plate Reader Software workspace."
      note "<b>2.</b> Check to see if input item is a #{plate_reader.valid_containers} if not, transfer samples to a valid container."
      note "<b>3.</b> Prepare measurement item with blanks."
      note "<b>4.</b>Take measurement, export data, & upload."
    end
    return plate_reader
  end

  def main
    pr = intro
    get_plate_reader_software(plate_reader: pr)
    operations.group_by {|op| op.input(MEASUREMENT_TYPE).val.to_sym}.each do |measurement_type, ops|
      new_mtype = true
      pr.measurement_type = measurement_type
      ops.each do |op|
        # Use class PlateReader to setup the experimental measurement
        pr.setup_experimental_measurement(experimental_item: op.input(INPUT).item, output_fv: op.output(OUTPUT))
        new_mtype = setup_plate_reader_software_env(pr: pr, new_mtype: new_mtype)
        # Gather materials and items
        media_item = get_media_bottle(op)
        take_items = [media_item].concat([pr.experimental_item].flatten)
        gather_materials(empty_containers: [pr.measurement_item], transfer_required: pr.transfer_required, new_materials: ['P1000 Multichannel'], take_items: take_items)
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


```
