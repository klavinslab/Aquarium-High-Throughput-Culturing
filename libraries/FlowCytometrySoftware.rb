# Eriberto Lopez
# elopez3@uw.edu
# 08/15/19

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
  
  # Retrieves the upload object from the upload show block and gathers the array of .fcs uploads
  def get_upload_array_from_show(up_show:, up_sym:)
    upload_array = up_show[up_sym].map {|up_hash| Upload.find(up_hash[:id]) }
    return upload_array
  end
  
  # Technician upload show block
  #
  # @param saving_dir [string] name of the directory that is created when all flow cytometery measurements are exported as .fcs files
  def upload_directory_show(saving_dir:)
    upload_var = "file"
    up_show = show do
      title "Upload Your Measurements"
      separator
      note "Select and Upload Directory: <b>#{saving_dir}</b>"
      upload var: upload_var.to_sym
    end
    return up_show, upload_var.to_sym
  end
end # module AqUpload

module KlavinsLabFlowCytometerSoftware
  include AqUpload
  
  # Groups sample type wells together to create an rc_list of a given sampletype in a collection.
  #
  # @params instrument [class] is a class instance of an instrument
  # @return sample_type_rc_list [Hash] is a hash of sample_type.names with a list of [r,c] tuples describing where that type of sample is in the collection that is being measured
  def get_sample_type_rc_list_hash(instrument)
    measurement_collection = collection_from(instrument.measurement_item)
    strain_sample_hash = Hash.new()
    measurement_collection.matrix.flatten.uniq.reject {|sid| sid == -1 }.each {|sid| strain_sample_hash[sid] = Sample.find(sid.to_i) }
    sample_type_rc_list_hash = Hash.new()
    measurement_collection.matrix.each_with_index do |row, r|
      row.each_with_index do |sid, c|
        if sid == -1
          next
        else
          if sample_type_rc_list_hash[strain_sample_hash[sid].sample_type.name].nil?
            sample_type_rc_list_hash[strain_sample_hash[sid].sample_type.name] = [[r, c]]
          else
            sample_type_rc_list_hash[strain_sample_hash[sid].sample_type.name].push([r, c])
          end
        end
      end
    end
    return sample_type_rc_list_hash
  end
  
  # Guides technician to select plate type in the flow cytometry software
  def select_plate_type(instrument)
    show do
      title "Setup #{instrument.type} Workspace"
      separator
      note "Select <b>Plate Type</b>: #{instrument.software.fetch(:plate_type_hash)[instrument.measurement_item.object_type.name.to_sym]}"
      image instrument.software.fetch(:images).fetch(:select_plate_type)
    end
  end
  
  # Guides technician through the steps in setting up the BD Acurri software workspace for culture measurements
  def setup_instrument_software(instrument)
    open_software(instrument)
    select_plate_type(instrument)
    get_sample_type_rc_list_hash(instrument).each do |sample_type_name, rc_list|
      if ALLOWABLE_FC_SAMPLETYPES.include? sample_type_name
        show do
          title "Select Wells"
          separator
          note "Select the following wells for #{sample_type_name} cultures found in #{instrument.measurement_item.object_type.name} #{instrument.measurement_item}."
          table highlight_alpha_rc(collection_from(instrument.measurement_item), rc_list) {|r,c| "#"}
          note 'After checking the wells on the screen continue to the next step.'
        end
        apply_settings(instrument: instrument)
      end
    end
  end
  
  # Creates a dummy 24 well tube rack to display on screen (deletes down stream)
  def get_tube_rack
    produce new_collection '24 Deep Well Plate'
  end
  
  # Guides technician through the steps in setting up the BD Acurri software workspace for calibration measurement
  def setup_instrument_calibration(instrument)
    open_software(instrument)
    select_plate_type(instrument)
    tube_rack = get_tube_rack 
    show do
      title "Select Wells"
      separator
      note "Select the following location of the optical particals #{instrument.measurement_item.object_type.name} #{instrument.measurement_item}."
      table highlight_alpha_rc(tube_rack, [[0,0]]) {|r,c| "#"}
      note 'After checking the wells on the screen continue to the next step.'
    end
    tube_rack.mark_as_deleted
    apply_settings(instrument: instrument)
  end
  
  # Guides technician to apply settings to the selected wells. Wells are selected by sampleType (different sampleTypes require different settings)
  def apply_settings(instrument:)
      log_info 'instrument.experimental_item.object_type.name.downcase', instrument.experimental_item.object_type.name.downcase
    if instrument.experimental_item.object_type.name.downcase.include? 'bead'
      sample_type_name = instrument.experimental_item.sample.sample_type.name.to_sym
    else
      sample_type_name = collection_from(instrument.experimental_item).matrix.flatten.uniq.reject {|sid| sid == -1 }.map {|sid| s = Sample.find(sid); s.sample_type.name }.uniq.first.to_sym
    end
    show do
      title "Apply Settings"
      separator
      image instrument.software.fetch(:images).fetch(:apply_settings)
      note "Apply the following settings to the wells you have selected"
      note "<b>Make sure that the settings are as follows:</b>"
      instrument.software.fetch(:sample_type_settings).fetch(sample_type_name).each {|setting, val| bullet "Set <b>#{setting}</b> to <b>#{val}</b>"}
      check "Finally, click <b>Apply Settings</b>"
      bullet "Save experimental measurement as <b>#{get_experiment_filename(instrument: instrument)}</b>"
    end
  end
  
  # Guides techician to read the culture plate, then export, save, and upload data to Aq
  def take_measurement_and_upload_data(instrument:)
    timepoint = read_plate(instrument: instrument)
    instrument.measurement_data = export_save_and_upload_measurement_data(instrument: instrument, timepoint: timepoint)
  end
  
  # Guides techician to read the calibration sample, then export, save, and upload data to Aq
  def take_calibration_and_upload_data(instrument:)
    timepoint = read_calibration(instrument: instrument)
    instrument.measurement_data = export_save_and_upload_measurement_data(instrument: instrument, timepoint: timepoint)
  end
  
  # Guides technician through software to export, save, and upload data to Aq
  def export_save_and_upload_measurement_data(instrument:, timepoint:)
    sw = instrument.software
    day = timepoint.strftime "%m%d%Y"
    hour = timepoint.strftime "%H%M"
    # Export
    fcs_exports = show do 
      title "Export .fcs files"
      separator
      note 'Make sure that flow cytometer run is <b>DONE!</b>'
      note 'Press <b>CLOSE RUN DISPLAY</b>'
      note 'Select <b>File</b> => <b>Export ALL Samples as FCS...</b> (see below)'
      image instrument.software.fetch(:images).fetch(:export_new_data)
      note 'You will see a pop-up like below, record the directory ID #'
      image instrument.software.fetch(:images).fetch(:new_export_directory)
      get 'text', var: 'dirname', label: 'Enter the name of the export directory in Desktop/FCS Exports/'
    end
    # UPLOAD
    if (!debug) 
      attempt = 0
      up_show, up_sym = {}, :file 
      while (up_show[up_sym].nil?) || (attempt == 3) do
        up_show, up_sym = upload_directory_show(saving_dir: sw[:saving_directory]+"/#{fcs_exports[:dirname]}")
        attempt += 1
      end
      upload_array = get_upload_array_from_show(up_show: up_show, up_sym: up_sym)
    else
      log_info 'UPLOADS Array debug'
      upload_array = [Upload.find(26482), Upload.find(26458)]
    end
    measurement_data = {
      mitem: instrument.measurement_item,
      day: day,
      hour: hour,
      uploads: upload_array
    }
    return measurement_data
  end
  
  # Directs techician to which lab and flow cytometer computer to setup workspace
  def go_to_computer(instrument)
    show do
      title "Go to the #{LAB_NAME} #{instrument.type} #{instrument.instrument_type}"
      separator
      warning "<b>The next steps should be done on the #{instrument.instrument_type} computer</b>.".upcase
    end
  end
  
  # Guides technician on how to open software if it is not already open
  def open_software(instrument)
    if (!instrument.software_open)
      go_to_computer(instrument)
      show do
        title "Open #{instrument.type} #{instrument.instrument_type} Software"
        separator
        note "Click on the icon shown below to open the #{instrument.instrument_type} software:"
        image instrument.software[:images][:open_software]
      end
      instrument.software_open = true
    else
      log_info 'the software is already open!'.upcase
    end
  end
  
  # Generates an experimental measurement filename, which is the name of the workspace created on the Accuri Flow Cytometer
  def get_experiment_filename(instrument:)
    timepoint = Time.now
    return "jid_#{jid}_experiment_#{instrument.measurement_item}_#{timepoint.strftime "%m%d%Y"}".gsub(' ', '')
  end
  
  # Guides technician through measuring the diluted calibration beads
  def read_calibration(instrument: instrument)
    go_to_computer(instrument)
    tube_rack = get_tube_rack
    show do
      title "Load #{instrument.measurement_item.object_type.name} #{instrument.measurement_item}"
      separator
      note "Click <b>Eject Plate</b>"
      check "Open tube #{instrument.measurement_item} then, place the tube into the first well of the #{instrument.software.fetch(:plate_type_hash)[instrument.measurement_item.object_type.name.to_sym]}."  
      bullet "Well A1 should be by the red sticker in the top left corner."
      table highlight_alpha_rc(tube_rack, [[0,0]]) {|r,c| "#"}
      check "Finally, load the #{instrument.measurement_item.object_type.name} and continue to the next step."
    end
    tube_rack.mark_as_deleted # Collection created for display, then deleted
    show do 
      title "Taking Measurements"
      separator
      note "Click <b>OPEN RUN DISPLAY</b>"
      image instrument.software.fetch(:images).fetch(:read_plate)
      note "Next, click <b>AUTORUN</b>"
      note "Contiue on to the next step while #{instrument.type} #{instrument.instrument_type} is running..."
    end
    instrument.measurement_item.location = instrument.type.to_s
    timepoint = Time.now
    return timepoint
  end
  
  # Guides technician through measuring the experimental culture plate
  def read_plate(instrument:)
    go_to_computer(instrument)
    show do
      title "Load #{instrument.measurement_item.object_type.name} #{instrument.measurement_item}"
      separator
      note "Click <b>Eject Plate</b>"
      note "Be sure that the plate is in the correct orientation. Well A1 should be by the red sticker in the top left corner."
      check "Finally, load the plate and continue to the next step."
    end
    show do 
      title "Taking Measurements"
      separator
      note "Click <b>OPEN RUN DISPLAY</b>"
      image instrument.software.fetch(:images).fetch(:read_plate)
      note "Next, click <b>AUTORUN</b>"
      note "Contiue on to the next step while #{instrument.type} #{instrument.instrument_type} is running..."
    end
    instrument.measurement_item.location = instrument.type.to_s
    timepoint = Time.now
    return timepoint
  end
  
  def get_measurement_filename(measurement_item:, timepoint:)
    mt = measurement_type.to_s.gsub(' ', '') 
    "jid_#{jid}_item_#{measurement_item.id}_t#{timepoint.strftime "%H%M"}_#{timepoint.strftime "%m%d%Y"}".gsub(' ', '_')
  end
end # module KlavinsLabFlowCytometrySoftware
