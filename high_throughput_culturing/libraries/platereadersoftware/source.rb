# Eriberto Lopez
# elopez3@uw.edu
# 03/14/19

require 'date'

module AqUpload
  # Provides a upload button in a showblock in order to upload a single file
  #
  # @param upload_filename [string] can be the name of the file that you want tech to upload
  # @return up_show [hash] is the upload hash created in the upload show block
  # @return up_sym [symbol] is the symbol created in upload show block that will be used to access upload
  def upload_show(saving_dir:, upload_filename:)
    upload_var = "file"
    up_show = show do
      title "Upload Your Measurements"
      separator
      note "Select and Upload: #{saving_dir}/<b>#{upload_filename}</b>"
      upload var: upload_var.to_sym
    end
    return up_show, upload_var.to_sym
  end
  
  # Retrieves the upload object from upload show block
  #
  # @param up_show [hash] is the hash that is created in the upload show block
  # @param up_sym [symbol] is the symbol created in the upload show block and used to access file uploaded
  # @return upload [upload_object] is the file that was uploaded in the upload show block
  def get_upload_from_show(up_show:, up_sym:)
    (!up_show[up_sym].nil?) ? (upload = up_show[up_sym].map {|up_hash| Upload.find(up_hash[:id])}.shift) : nil #(show {warning "no upload was found".upcase})
  end
end

module KlavinsLabPlateReaderSoftware
  include AqUpload
  
  def setup_plate_reader_software_env(pr:, new_mtype:)
    open_software(pr: pr)
    new_mtype = select_measurement_type_template(pr: pr) if new_mtype
    preheat(pr: pr)
    return new_mtype
  end

  def take_measurement_and_upload_data(pr:)
    timepoint = read_plate(pr: pr)
    pr.measurement_data = export_save_and_upload_measurement_data(pr: pr, timepoint: timepoint)
  end

  def export_save_and_upload_measurement_data(pr:, timepoint:)
    sw = pr.software
    day = timepoint.strftime "%m%d%Y"
    hour = timepoint.strftime "%H%M"
    measurement_data = [] # Collect uploads for a measurement_item's measurement_type(s) ie: 'Optical Density & Green Fluorescence'
    export_measurement_types(pr: pr).each do |mt|
      measurement_filename = get_measurement_filename(measurement_item: pr.measurement_item, measurement_type: mt, timepoint: timepoint)
      show do
        title "Export & Save #{mt} Measurements Plate Reader"
        separator
        warning "Make sure that no other Excel sheets are open before exporting!".upcase
      end
      show do
        title "Export & Save #{mt} Measurements Plate Reader"
        separator
      # EXPORT
        image sw[:images][:export_new_data]
        bullet "Select the <b>'Statistics'</b> tab"
        bullet "Select Data: <b>#{sw[:export_mesurement_type][mt.to_sym][:dtype]}</b>"
        note "Next, click the Excel sheet export button. <b>The sheet will appear on the menu bar below</b>."
        image sw[:images][:export_data_button]
      # SAVE
        warning "Make sure to save file as a '.csv' file!!"
        note "Go to sheet and <b>'Save as'</b> ==> <b>#{measurement_filename}</b> under the <b>#{sw[:saving_directory]}</b> folder."
        image sw[:images][:save_export]
      end
      # UPLOAD
      attempt = 0
      up_show, up_sym = {}, nil #upload_show(saving_dir: sw[:saving_directory], upload_filename: measurement_filename)
      while ((up_show[up_sym].nil?) || (attempt == 3)) && (!debug) do
        up_show, up_sym = upload_show(saving_dir: sw[:saving_directory], upload_filename: measurement_filename)
        attempt+=1
      end
      upload = get_upload_from_show(up_show: up_show, up_sym: up_sym)
      upload_data = {
        mitem: pr.measurement_item,
        mt: mt.to_s.gsub(' ','_'),
        day: day,
        hour: hour,
        upload: upload
      }
      measurement_data.push(upload_data)
    end
    return measurement_data
  end

  def go_to_computer
    show {warning "<b>The next steps should be done on the plate reader computer</b>.".upcase}
  end
  
  def open_software(pr:)
    if (!pr.software_open)
      go_to_computer
      show do
        title "Open #{pr.type} Plate Reader Software"
        separator
        note "Click on the icon shown below to open the plate reader software:"
        image pr.software[:images][:open_software]
      end
    else
      log_info 'the software is already open!'.upcase
    end
    pr.software_open = true
  end
  
  def select_measurement_type_template(pr:)
    mt_template = pr.software[:measurement_type_templates][pr.measurement_type.to_sym]
    show do 
      title "Select #{pr.type} #{pr.measurement_type.to_s} Template"
      separator
      note "Under <b>'Create a New Item'</b> click <b>'Experiment'</b>"
      note "From the pop-up list select: <b>#{mt_template}</b>"
    end
    new_mtype = false
    return new_mtype # the measurement_type is no longer new and can be reaused if necessary
  end
  
  def preheat(pr:)
    show do 
      title "Warming Up..."
      separator
      note "Let the #{pr.type} Plate Reader warm up if necessary."
      note "In the following preparative steps, minimize the amount of time that the 
      <b>#{ObjectType.find(pr.experimental_item.object_type_id).name} #{pr.experimental_item}</b>
      is not under experimental conditions prior to the measurement."
    end 
  end
  
  def get_experiment_filename(pr:, timepoint:)
    "jid_#{jid}_experiment_#{pr.measurement_type}_#{timepoint.strftime "%m%d%Y"}".gsub(' ', '')
  end

  def read_plate(pr:)
    go_to_computer
    timepoint = Time.now
    show do 
      title "Take #{pr.measurement_type} Measurement"
      separator
      note "Click Read Plate icon shown below"
      image pr.software[:images][:read_plate]
      note "Next, click the <b>'READ'</b> on the pop-up window."
      bullet "Name experiment file: <b>#{get_experiment_filename(pr: pr, timepoint: timepoint)}</b>"
      bullet "<b>Save</b> it under the <b>#{pr.software[:saving_directory]}</b> folder."
      note "Finally, load plate #{pr.measurement_item} then, click <b>'OK'</b> to take measurement"
    end
    pr.measurement_item.location = pr.type.to_s
    return timepoint
  end
  
  def get_measurement_filename(measurement_item:, measurement_type:, timepoint:)
    mt = measurement_type.to_s.gsub(' ', '') 
    "jid_#{jid}_#{mt}_item_#{measurement_item.id}_t#{timepoint.strftime "%H%M"}_#{timepoint.strftime "%m%d%Y"}".gsub(' ', '_')
  end
  
  def export_measurement_types(pr:)
    mt = pr.measurement_type.to_s
    case mt
    when 'Optical Density', 'Time Series', 'Green Fluorescence'
      [mt]
    when 'Optical Density & Green Fluorescence'
      mt.split(' & ')
    when 'Calibration'
      ["#{mt} Optical Density", "#{mt} Green Fluorescence"]
    else
      raise "#{pr.measurement_type} is not supported by this plate reader or does not have the measurement_type added to the #{pr.type} software properties"
    end
  end
end # module Gen5BioTekSoftware
