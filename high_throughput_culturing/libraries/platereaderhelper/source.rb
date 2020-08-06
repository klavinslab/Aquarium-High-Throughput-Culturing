# Eriberto Lopez
# elopez3@uw.edu
# 07/23/19

needs "Standard Libs/Debug"
needs "Standard Libs/Units"
needs "Standard Libs/AssociationManagement"
needs "High Throughput Culturing/InstrumentHelper"
needs "High Throughput Culturing/PlateReaderSoftware"
needs "High Throughput Culturing/PlateReaderConstants"
needs "High Throughput Culturing/PlateReaderCalibration"
needs "Collection Management/CollectionDisplay"

class PlateReader 
  include InstrumentHelper
  attr_accessor :software_open
  attr_reader :type, :valid_containers, :software
  def initialize()
    @type             = get_my_plate_reader_type
    @valid_containers = valid_containers
    @software         = get_my_software_properties
    @software_open    = false
  end
  
  def get_my_plate_reader_type
    PLATE_READER_TYPE[LAB_NAME]
  end

  def valid_containers
    get_my_plate_reader_properties_obj[type][:valid_containers]
  end
  
  def get_my_plate_reader_properties_obj
    MY_PLATE_READER_PROPERTIES[LAB_NAME]
  end
  
  def get_my_software_properties
    get_my_plate_reader_properties_obj[type][:software_properties]
  end
  
  def valid_container?
    if experimental_item.instance_of? Collection
      valid_containers.include? experimental_item.object_type.name.to_s
    elsif experimental_item.instance_of? Item
      valid_containers.map {|c| ObjectType.find_by_name(c).id.to_i}.include? experimental_item.object_type_id.to_i
    elsif experimental_item.instance_of? Array
      valid_container = false
      ot_arr = ObjectType.find(experimental_item.map {|item| item.object_type_id}.uniq).map {|ot| ot.name}
      ot_arr.each {|otn| (valid_containers.include? otn) ? (valid_container = true) : (valid_container) }
      valid_container
    else
      raise "This type of #{experimental_item.class} object is not compatible with this instrument"
    end
  end
end # Class PlateReader  

module PlateReaderHelper
  include Units, Debug, AssociationManagement
  include CollectionDisplay
  include PlateReaderCalibration
  
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
      note "<b>4.</b> Take measurement, export data, & upload."
    end
    get_plate_reader_software(plate_reader: plate_reader)
    return plate_reader
  end
  
  # when PlateReaderHelper is included into class Protocol we can use the class method .include() 
  # to include the required software module dynamically to the Protocol. 
  # Which allows us to use methods found in the software module.
  def get_plate_reader_software(plate_reader:)
    case plate_reader.type
    when 'Gen 5 BioTek'.to_sym
      Protocol.include(KlavinsLabPlateReaderSoftware)
    when 'YOUR_LABS_PLATE_READER_MODULE'.to_sym
      Protocol.include(YourSoftwareSteps)
    else
      raise "the #{plate_reader.type} plate reader in the #{LAB_NAME} has no software steps associated to it, create a module with steps to use plate reader".upcase
    end
  end
  
  # If a dilution is required then find how much media an culture are required given the working volume of the container.
  def get_culture_and_media_vols(dilution_factor:, measurement_item:)
    working_vol = get_object_type_data(collection: measurement_item).fetch('working_vol').split('_').first.to_f
    cult_vol_ul = (dilution_factor == 'None') ? working_vol : dilution(dilution_factor: dilution_factor, vol: working_vol)
    media_vol_ul = working_vol - cult_vol_ul
    return media_vol_ul, cult_vol_ul
  end
  
  def copy_sample_matrix(from_collection:, to_collection:)
    sample_matrix = from_collection.matrix
    to_collection.matrix = sample_matrix
    to_collection.save()
  end
  
  def transfer_part_associations(from_collection:, to_collection:)
    copy_sample_matrix(from_collection: from_collection, to_collection: to_collection)
    from_collection_associations = AssociationMap.new(from_collection)
    to_collection_associations   = AssociationMap.new(to_collection)
    from_associations_map = from_collection_associations.instance_variable_get(:@map)
    # Remove previous source data from each part, retain only value where the key is part_data
    from_associations_map.select! {|key| key == 'part_data' } # Retain only the part_data, so that global associations do not get copied over
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("source") ? part.reject! {|k| k == "source" } : part } }
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("destination") ? part.reject! {|k| k == "destination" } : part } }
    # Set edited map to the destination collection_associations
    to_collection_associations.instance_variable_set(:@map, from_associations_map) # setting it to the associations @map will push the part_data onto each part item automatically
    to_collection_associations.save()
    return from_associations_map
  end    
    
  def part_provenance_transfer(from_collection:, to_collection:, process_name:)
    to_collection_part_matrix = to_collection.part_matrix
    from_collection.part_matrix.each_with_index do |row, r_i|
      row.each_with_index do |from_part, c_i|
        if from_part
          to_part = to_collection_part_matrix[r_i][c_i]
          # Create source and destination objs
          source_id = from_part.id; source = [{id: source_id }]
          destination_id = to_part.id; destination = [{id: destination_id }]
          # raise process_name.inspect unless process_name.nil?
          destination.first.merge!({additional_relation_data: { process: process_name }}) unless process_name.nil?
          # Association source and destination
          to_part.associate(key=:source, value=source)
          from_part.associate(key=:destination, value=destination)
        end
      end
    end
  end
  
  def stamp_transfer(from_collection:, to_collection:, process_name: nil)
    from_associations_map = transfer_part_associations(from_collection: from_collection, to_collection: to_collection)
    part_provenance_transfer(from_collection: from_collection, to_collection: to_collection, process_name: process_name)
    return from_associations_map.fetch('part_data')
  end
  
  def update_matrix(matrix:, &block)
    matrix.map! {|row| row.map! {|part_data| yield part_data } }
  end
 
  def update_part_data_matrix(collection:, &block)
    collection_associations = AssociationMap.new(collection_from(collection))
    part_data_matrix = collection_associations.instance_variable_get(:@map).fetch('part_data', Array.new(collection.object_type.rows) { Array.new(collection.object_type.columns) { Hash.new() }})
    update_matrix(matrix: part_data_matrix) {|part_data| yield part_data }
    collection_associations.instance_variable_set(:@map, {'part_data'=>part_data_matrix})
    collection_associations.save()
  end
  
  def transfer_culture_volume(pr:, culture_vol_ul:,  media_vol_ul:)
    total_transfer_volume = culture_vol_ul + media_vol_ul
    from_collection = collection_from(pr.experimental_item)
    to_collection = collection_from(pr.measurement_item)
    part_data_matrix = stamp_transfer(from_collection: from_collection, to_collection: to_collection, process_name: 'dilution')
    
    # Remove volume from Culture_Volume attribute
    update_part_data_matrix(collection: from_collection) do |part_data| culture_volume = part_data.fetch('Culture_Volume', false)
      if culture_volume
        culture_volume[:qty] = culture_volume[:qty] - culture_vol_ul
        part_data['Culture_Volume'] = culture_volume
      end
      part_data
    end
    # Add transfer volume to new collection
    update_part_data_matrix(collection: to_collection) do |part_data| culture_volume = part_data.fetch('Culture_Volume', false)
      if culture_volume
        culture_volume[:qty] = total_transfer_volume
      else
        culture_volume = {qty: total_transfer_volume, units: "#{MICROLITERS}"}
      end
      part_data['Culture_Volume'] = culture_volume
      part_data
    end
  end

  def get_part_culture_volumes(collection:)
    collection.data_matrix_values('Culture_Volume')
  end
  
  def tech_prefill_and_transfer(pr:, media_sample:, media_vol_ul:, culture_vol_ul:)
    pr.measurement_item = transfer_sample_matrix(source_collection: pr.experimental_item, destination_collection: pr.measurement_item)
    prefill_plate_w_media(collection: pr.measurement_item, media_sample: media_sample, media_vol_ul: media_vol_ul)
    tech_transfer_samples(culture_vol_ul: culture_vol_ul, sources: pr.experimental_item, destinations: pr.measurement_item)
    # update "Culture_Volume" for the parts that were transfered based on the "working_vol"
    transfer_culture_volume(pr: pr, culture_vol_ul: culture_vol_ul, media_vol_ul: media_vol_ul)
  end
  
  # TODO: Make opts hash allow usner to use to transfer sample matrix by some offset index  
  def transfer_sample_matrix(source_collection:, destination_collection:) #, opt: {starting_idx: [0,0]})
    destination_collection = collection_from(destination_collection)
    source_collection = collection_from(source_collection)
    if (source_collection.dimensions == destination_collection.dimensions)
      source_matrix = source_collection.matrix
      destination_collection.matrix = source_matrix
    else
      destination_collection.matrix = source_collection.matrix.flatten.each_slice(destination_collection.object_type.columns).map {|row| row }
    end
    destination_collection.save()
    return destination_collection
  end
  
  def prefill_plate_w_media(collection:, media_sample:, media_vol_ul:, display_hash: {})
    if !display_hash.empty? || media_vol_ul > 0.0 
      collection = collection_from(collection) 
      show do
        title "Pre-fill #{collection.object_type.name} #{collection}"
        separator
        note "Follow the table below to pre-fill the collection with <b>#{media_sample.name}</b> prior to transferring and resuspending cultures:"
        table highlight_alpha_non_empty(collection) {|r,c| ((display_hash.empty?) ? ("#{media_vol_ul}#{MICROLITERS}") : ("#{display_hash[r][c][:media_vol_ul]}#{MICROLITERS}")) }
      end
    end
  end

  def tech_transfer_samples(culture_vol_ul:, sources:, destinations:) 
    alpha_numeric = coordinates_96
    destination_coll = collection_from(destinations)
    source_coll = collection_from(sources)
    source_alpha = source_coll.get_non_empty.map {|r, c| alpha_numeric[r][c] }
    source_alpha_hashmap = nested_hash_data_structure
    destination_coll.get_non_empty.each_with_index do |rc, alpha_idx|
      r, c = rc
      source_alpha_hashmap[r][c] = source_alpha[alpha_idx]
    end
    show do 
      title "Transferring Samples <b>From</b> #{source_coll} <b>To</b> #{destination_coll}"
      separator
      note "Follow the table below to transfer cultures <b>To #{destination_coll}</b>:"
      bullet "The alpha numeric coordinates coorespond to wells in #{source_coll}"
      bullet "Transfer #{culture_vol_ul}#{MICROLITERS} of culture <b>From</b> each well of #{sources}"
      table highlight_alpha_non_empty(destination_coll) {|r,c| "#{source_alpha_hashmap[r][c]}"}
    end
  end

  def add_blanking_samples_to_measurement_item(measurement_item:, blanking_sample:, num_blanks: 3)
    measurement_collection = (measurement_item.instance_of? Collection) ? (measurement_item) : (collection_from(measurement_item))
    count = 0
    blank_wells = []
    while ((measurement_collection.get_empty.length != 0) && (count != num_blanks)) do
      r, c, x = measurement_collection.add_one(blanking_sample, reverse: true)
      create_part_association(collection: measurement_collection, key: "Plate Reader Blanks", row: r, col: c, val: "jid_#{jid}")
      blank_wells.push([r,c])
      count+=1
    end
    measurement_collection.save()
    return measurement_collection, blank_wells    
  end
  
  def create_part_association(collection:, key:, row:, col:, val:)
    part = collection_from(collection).set_part_data(key, row, col, val)
    part.save()
  end

  def tech_add_blanks(pr:, blanking_sample:, culture_vol_ul:, media_vol_ul:)
    max_well_vol_ul = get_max_well_vol(culture_vol_ul: culture_vol_ul, media_vol_ul: media_vol_ul)
    measurement_collection, blank_wells = add_blanking_samples_to_measurement_item(measurement_item: pr.measurement_item, blanking_sample: blanking_sample)
    blank_wells.each {|row, col| create_part_association(collection: measurement_collection, key: 'Culture_Volume', row: row, col: col, val: {qty: culture_vol_ul+media_vol_ul, units: "uL"}) }
    show do
      title "Adding #{blanking_sample.name} Blanks to #{measurement_collection}"
      separator
      note "Follow the table below to add #{max_well_vol_ul}#{MICROLITERS} of #{blanking_sample.name} to the appropriate wells:"
      table highlight_alpha_rc(measurement_collection, blank_wells) {|r,c| "#{max_well_vol_ul}#{MICROLITERS}"}
    end
  end
  
  def data_attributes(data:)
    return data[:mt].to_sym, data[:day].to_sym, data[:hour].to_sym, data[:mitem]
  end
  
  # TODO: Error handling when processing and associating upload data
  # Associate to the valid container and correct the data. 
  def process_and_associate_data(pr:, ops:, dilution_factor: 'None', blanking_sample: nil)
    pr.measurement_data.each do |data|
      mt, day, hour, mitem = data_attributes(data: data)
      key = "#{mt}_#{day}_#{hour}"
      upload = (debug) ? Upload.find(11379) : data[:upload]
      associate_data(object=mitem, key=key, data=upload, opts = {}) # Associate upload to object #=> Standard Libs/AssociationManagement
      ops.each {|op| associate_data(object=op.plan, key=key, data=upload, opts = {})} # Associates upload to plans
      if pr.measurement_type == 'Calibration'
        # Process data and create standard curve and optical item volume correction factor
        create_prm_calibration_associations(ops: ops, upload: upload, mitem: mitem, mt: mt)
      else
        # Process upload into corrected_data_matrix
        raw_data_matrix = extract_measurement_matrix_from_csv(upload: upload) 
        blanked_data_matrix, corrected_data_matrix = correct_plate_reader_data(
                                                      pr: pr,
                                                      blanking_sample: blanking_sample,
                                                      data_matrix: raw_data_matrix,
                                                      dilution_factor: dilution_factor
                                                    )
        # Associate to collection
        create_prm_part_associations_for_collection(
          collection: pr.measurement_item,
          data_matrix: corrected_data_matrix,
          measurement_type: mt,
          day: day,
          hour: hour
        ) 
        create_prm_part_associations_for_collection(
          collection: pr.experimental_item,
          data_matrix: corrected_data_matrix,
          measurement_type: mt,
          day: day,
          hour: hour
        ) unless !pr.transfer_required
      end
      # Filters operations that have a culture as input
      create_prm_item_association_for_cultures(ops: ops, mt: mt, day: day, hour: hour, corrected_data_matrix: corrected_data_matrix)
      ops.each {|op| associate_data(object=op, key=key, data={upload_id: upload.id}, opts = {})} # Associates upload_id to operation
    end
  end
  
  def associate_calibration_data(ops, mitem, measurement_type, cal_hash, calc_calibration_data)
    key = measurement_type
    associations = AssociationMap.new(mitem)
    case measurement_type
    when :Calibration_Green_Fluorescence
      trendline_points = {uM_to_val: cal_hash}
      associations.put(key, trendline_points) # ie: 'Calibration_Green_Fluorescence' : {'uM_to_val'=>{50=>2400,25=>1234...}}
      calibration_obj = {standard_curve: calc_calibration_data}
    when :Calibration_Optical_Density
      optical_pts = {vol_to_factor: cal_hash}
      calibration_obj = {vol_to_factor: calc_calibration_data}
      associations.put(key, optical_pts)
    else
      raise "this is not a recognized measurement_type: #{measumrenent_type}"
    end
    ops.each {|op| 
      associate_data(object=op,      key=key, data=calibration_obj, opts = {})
      associate_data(object=op.plan, key=key, data=calibration_obj, opts = {})
    }
    associations.put(key, calibration_obj)
    associations.save
  end
  
  def create_prm_calibration_associations(ops:, upload:, mitem:, mt:)
    data_matrix = extract_measurement_matrix_from_csv(upload: upload) unless debug
    data_matrix = Array.new(8){Array.new(12) { rand(10) } }
    cal_hash = get_calibration_hash(dm: data_matrix, measurement_type: mt)
    calcd_calibration_data = get_calibration_calculated_values(cal_hash: cal_hash, measurement_type: mt)
    associate_calibration_data(ops, mitem, mt, cal_hash, calcd_calibration_data)
  end  

  def create_prm_item_association_for_cultures(ops:, mt:, day:, hour:, corrected_data_matrix:) 
    alpha_coords = coordinates_96
    ops.select {|op| !op.input('Cultures').nil? }.each do |op|
      out_fv, r, c = op.outputs[0],  op.outputs[0].row, op.outputs[0].column
      destination_part, m_val = "#{out_fv.collection.id}/#{alpha_coords[r][c]}", corrected_data_matrix[r][c]
      input_culture = (debug) ? Item.find(234809) : op.input('Cultures').item
      input_cult_associations = AssociationMap.new(input_culture)
      current_da = input_cult_associations.get(mt.to_s) 
      if current_da.nil?
        # Create a new entry under the mt key
        current_da = nested_hash_data_structure
        current_da[day][destination_part][hour] = m_val
      else
        if current_da.has_key? day.to_s
          current_da[day][destination_part] = { hour => m_val }
        else
          current_da[day] = {destination_part => { hour => m_val } }
        end
      end
      input_cult_associations.put(mt.to_s, current_da)
      input_cult_associations.save
    end
  end  
  
  def keep_transfer_plate(pr:, user_val:)
    pr.measurement_item.location = (user_val == 'YES') ? 'Bench' : 'deleted'
  end
  
  def cleaning_up(pr:)
    clean_up_inputs([])
    clean_up_outputs
  end

  # Cleanup input items
  #
  # @param release_arr [array] is an array of items that are found in Aq
  def clean_up_inputs(release_arr)
    operations.store(opts = { interactive: true, method: 'boxes', errored: false, io: 'input' })
    release release_arr, interactive: true
    # operations.store
  end

  # Cleanup output items
  def clean_up_outputs()
    operations.store(interactive: true, method: 'boxes', errored: false, io: 'output')
    show do
      title "Cleaning Up"
      separator
      note "Return any remaining reagents used and clean bench"
    end
  end
  
  def create_prm_part_associations_for_collection(collection:, data_matrix:, measurement_type:, day:, hour:)
    collection_from(collection).get_non_empty.each do |r, c|
      pa = collection_from(collection).get_part_data(key=measurement_type, row=r, col=c)
      if pa.nil? || pa == -1
        pa = {day => {hour => data_matrix[r][c]} }
      else
        (pa.keys.include? day.to_s) ? pa[day].merge!({hour => data_matrix[r][c]}) : pa[day] = {hour => data_matrix[r][c]}
      end
      create_part_association(collection: collection, key: measurement_type, row: r, col: c, val: pa)
    end
  end

  def get_part_association_data_matrix(collection:, key:)
    matrix = Array.new(collection.object_type.rows) {Array.new(collection.object_type.columns) {-1} }
    part_data_arr = get_collection_part_data(collection: collection, key: key)
    collection.get_non_empty.zip(part_data_arr).each do |rc, data|
      r, c = rc
      matrix[r][c] = data
    end
    return matrix
  end
  
  def average_arr_values(arr)
    arr.reduce(:+) / arr.size.to_f
  end
  
  def get_sample_wells(collection:, sample:)
    collection_from(collection).find(sample)
  end
  
  def apply_value_to_matrix(matrix:, value:, operator:, &block)
    if block_given?
      matrix.map {|row| row.map {|part| (!part.nil? || part != -1) ? yield(part, value) : -1 } }
    else
      matrix.map {|row| row.map {|part| (!part.nil? || part != -1) ? (part.send(operator, value)) : (-1) } } 
    end
  end
  
  def correct_plate_reader_data(pr:, blanking_sample:,  data_matrix:, dilution_factor:)
    # Get blank wells
    blanking_wells = get_sample_wells(collection: pr.measurement_item, sample: blanking_sample)
    blanking_value = average_arr_values( blanking_wells.map {|r, c| data_matrix[r][c]} )
    blanked_data_matrix = apply_value_to_matrix(matrix: data_matrix, operator: '-', value: blanking_value)
    # Apply dilution factor to the measurement to calc the experimental_item/source measurement value
    if dilution_factor.is_a? Array 
      # Create a dilution_factor_matrix that has the same dimensions as the collection default value is 'None' dilution
      r, c = collection_from(pr.measurement_item).object_type.rows, collection_from(pr.measurement_item).object_type.columns
      dilution_matrix = Array.new(r) {Array.new(c) { 'None'} }
      # Take dilution_factor array and slice by the dimensions of the collection, next place all of the df into dilution_matrix
      dilution_factor.each_slice(c).map {|s| s}.each_with_index {|s, ridx| 
        s.each_with_index {|dil, cidx| dilution_matrix[ridx][cidx] = dil } }
      # Finally, either apply the dilution factor (df) or take the value from the blanked data matrix
      corrected_data_matrix = dilution_matrix.each_with_index.map {|row, r_idx| row.each_with_index.map {|df, c_idx|
          (df == 'None') ? (blanked_data_matrix[r_idx][c_idx]) : (blanked_data_matrix[r_idx][c_idx] * 1/df)
        }
      }
    else
      corrected_data_matrix = (dilution_factor == 'None') ? (blanked_data_matrix) : (apply_value_to_matrix(matrix: blanked_data_matrix, operator: '*', value: 1/dilution_factor))
    end
    return blanked_data_matrix, corrected_data_matrix
  end
  
  def change_item_location(item:, location:)  
    item.location = location
    item.save()
  end
  
  def get_parameter(op:, fv_str:)
    op.input(fv_str).val
  end
  
  def get_dilution_factor(op:, fv_str:)
    param_val = get_parameter(op: op, fv_str: fv_str).to_s
    dilution_factor = (param_val == 'None') ? param_val : param_val.chomp('X').to_f
  end
  
  def get_object_type_data(collection:)
    JSON.parse(Collection.find(collection.id).object_type.data)
  end
    
  def dilution(dilution_factor:, vol:)
    dilution_factor.to_f * vol.to_f
  end
  
  def get_media_bottle(op)
    op.input('Media').item
  end
  
  # A way to filter Struct objects (depriciated)
  # ie: catalog(pr.measurement_data, by: :item) #=> sorting symbol should be known by user. It is a instance method created in a Struct class
  def catalog(collection, by:)
    catalog = Hash.new { |hash, key| hash[key] = [] }
    collection.each_with_object(catalog) do |item, catalog|
      catalog[item.send(by)] << item
    end
  end
  
  def get_max_well_vol(culture_vol_ul:, media_vol_ul:)
    culture_vol_ul + media_vol_ul
  end
  
  def coordinates_96 
    ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}}
  end
  
  # could extend a module with common class variables needed in protocol writing
  def gather_materials(empty_containers: [], transfer_required: false, new_materials: [], take_items: [])
    new_materials = new_materials.select {|m| !Protocol.materials_list.include? m}
    if !new_materials.empty?
      show do
        title "Gather The Following Materials"
        separator
        note "Gather the following and bring them to your bench:"
        empty_containers.each {|c|
          ((c.is_a? Item) || (c.is_a? Collection)) ? (check "#{c.object_type.name} and label as <b>#{c.id}</b>") : (check "#{c}")
        }
        new_materials.each {|m| check "#{m}" }
      end 
    end
    take take_items, interactive: true 
    Protocol.materials_list.concat(new_materials).concat(empty_containers)
  end
  
  # Allows for multiple key deeply nested hash[:item][:measurement][:day][:hour] = val
  def nested_hash_data_structure
    Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
  end
  
  def get_transfer_display_hash(ops:, input_str:, output_str:, dilution_str:)
    display_hash = nested_hash_data_structure
    ops.each do |op|
      out_fv = op.output(output_str)
      dilution_factor = get_dilution_factor(op: op, fv_str: dilution_str)
      media_vol_ul, cult_vol_ul = get_culture_and_media_vols(dilution_factor: dilution_factor, measurement_item: op.output(output_str).collection)
      dh = display_hash[out_fv.row][out_fv.column]
      dh[:dilution_factor] = dilution_factor
      dh[:item_id] = op.input(input_str).item.id
      dh[:media_vol_ul] = media_vol_ul
      dh[:cult_vol_ul] = cult_vol_ul
      create_part_association(collection: op.output(output_str).collection, key: :source, row: out_fv.row, col: out_fv.column, val: op.input(input_str).item.id)
    end
    display_hash
  end
  
  def tech_transfer_cultures(collection:, display_hash:)
    collection = collection_from(collection)
    show do
      title "Transfer Cultures to #{collection.object_type.name} #{collection}"
      separator
      note "Follow the table below to transfer the correct volume and culture to the appropriate well:"
      table highlight_alpha_non_empty(collection) {|r, c| "item_#{display_hash[r][c][:item_id]}\n#{display_hash[r][c][:cult_vol_ul]}#{MICROLITERS}" }
    end
  end
  
  def get_uninitialized_output_fv_object_type_id(op)
    AllowableFieldType.find(op.outputs[0].allowable_field_type_id).object_type_id
  end
  
  def get_uninitialized_output_object_type(op)
    oti = get_uninitialized_output_fv_object_type_id(op)
    ObjectType.find(oti)
  end
  
  # TODO: Make compataible with both statistics and matrix uploads
  # Takes in a csv upload file, extracts the information on it
  # into a datamatrix object which is returned.
  # Specificly tuned to the output file of the biotek plate reader.
  #
  # @param upload [Upload]  the object which can be resolved to calibration csv
  # @return [WellMatrix]  a WellMatrix holding the measurement for each well
  def extract_measurement_matrix_from_csv(upload:)
    table = parse_upload_csv(upload: upload)
    # dm = (table.length > 25) ? Array.new(8) { Array.new(12) {-1} } : Array.new(4) { Array.new(6) {-1} }
    dm =  Array.new(8) { Array.new(12) {-1} } 
    # If the file that is saved, exported, and uploaded was formatted as a 'Statistics' table
    table.each_with_index do |row, idx|
      next if idx.zero?
      well_coord = row[2]
      next if well_coord.nil?
      measurement = row[3].to_f
      next if measurement.nil?
      r, c = find_rc_from_alpha_coord(well_coord).first
      (dm[r][c]) ? dm[r][c] = measurement : -1
    end
    dm
  end
  
  def parse_upload_csv(upload:)
    require 'csv'
    require 'open-uri'
    table = []
    CSV.new(open(upload.expiring_url)).each { |line| table.push(line) }
    return table
  end

  # Finds where an alpha_coordinate is in a 96 Well plate
  #
  # @param alpha_coord [array or string] can be a single alpha_coordinate or a list of alpha_coordinate strings ie: 'A1' or ['A1','H7']
  # @return rc_list [Array] a list of [r,c] coordinates that describe where the alpha_coord(s) are in a 96 well matrix
  def find_rc_from_alpha_coord(alpha_coord)
    # look for where alpha coord is 2-D array coord
    coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
    rc_list = []
    if alpha_coord.instance_of? Array
      # alpha_coord = alpha_coord.map {|a| a.upcase}
      alpha_coord.each {|a_coord|
        (!a_coord.nil?) ? coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == a_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } } : next
      }
    else
      coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == alpha_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } }
    end
    return rc_list
  end
  
  def add_solution_to_op(op:, fv_str:, item:)
    if item.instance_of? Collection
      ot = item.object_type
    elsif item.instance_of? Item
      ot = ObjectType.find(item.object_type_id)
    end
    t = op.add_input(fv_str, item.sample, ot)
    op.input(fv_str).set item: item
  end
    
end # module PlateReaderHelper