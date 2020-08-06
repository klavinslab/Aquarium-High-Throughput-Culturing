needs "Standard Libs/Units"
needs "Standard Libs/AssociationManagement"
htc = "High Throughput Culturing/"
needs htc + "FlowCytometryConstants"
needs htc + "FlowCytometrySoftware"
needs htc + "InstrumentHelper"
needs htc + "HighThroughputHelper"

# This class instantiates a representation of a Flow Cytometer instrument, in order for Aq to interact with this type of instrument
#
# @author Eriberto Lopez - elopez3@uw.edu
# @since 08/16/19
# 
# @attr [boolean] software_open describes the state of the software for the flow cytometer
# @attr_reader [String] instrument_type describes the type of instruement
# @attr_reader [String] type describes the model of instrument
# @attr_reader [Array] valid_containers describes the types of containers that can be measured by the flow cytometer
# @attr_reader [Hash] software is a hash object that comes from FlowCytometryConstants Library
class FlowCytometer
  include InstrumentHelper
  attr_accessor :software_open
  attr_reader :instrument_type, :type, :valid_containers, :software, :lab_name
  def initialize()
    @lab_name         = get_lab_name
    @instrument_type  = 'Flow Cytometer'.freeze
    @type             = get_my_flow_cytometer_type
    @valid_containers = valid_containers
    @software         = get_my_software_properties
    @software_open    = false
  end

  #Checks what server AQ is being run on so it can decide what instruments are available to use
  #Assumes that the BioFAB server will only be run in BIOFAB and no where else
  def get_lab_name
    aq_instance = Bioturk::Application.config.instance_name.upcase
    if aq_instance == "UW BIOFAB"
      return KLAVINS_LAB.to_sym
    elsif aq_instance == "DARPA_SD2"
      return HAASE_LAB.to_sym
    else
      return HAASE_LAB.to_sym
    end
  end
  
  def get_my_flow_cytometer_type
    #raise "lab name #{lab_name}"
    FLOW_CYTOMETER_TYPE[lab_name.to_sym]
  end

  def valid_containers
    get_my_flow_cytometer_properties_obj[type][:valid_containers]
  end
  
  def get_my_flow_cytometer_properties_obj
    MY_FLOW_CYTOMETER_PROPERTIES[lab_name.to_sym]
  end
  
  def get_my_software_properties
    get_my_flow_cytometer_properties_obj[type][:software_properties]
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
    elsif experimental_item.class == "NillClass"
      raise "Your input plate is of class #{experimental_item.class} which means it was likley deleted"
    else
      raise "This type of #{experimental_item.class} object is not compatible with this instrument"
    end
  end
  
end # class FlowCytometer

module FlowCytometryHelper
  include Units, AssociationManagement
  
  def intro
    flow_cytometer = FlowCytometer.new
    show do
      title "Flow Cytometry Measurements"
      separator
      note "This protocol will instruct you on how to take measurements on the #{flow_cytometer.type} Flow Cytometer."
      note "A flow cytomter uses lasers to phenotypically characterize a microbial culture."
      note "This per cell measurement quantifies a cell's size, shape, and color. Making it a useful tool to analyze & distiguish cellular populations from each other."
      note "In this protocol, you will prepare the instrument workspace and characterize your genetically modified organism."
      note "<b>1.</b> Setup #{flow_cytometer.type} Flow Cytomter Software workspace."
      note "<b>2.</b> Check to see if input item is a #{flow_cytometer.valid_containers} if not, transfer samples to a valid container."
      note "<b>3.</b> Load plate."
      note "<b>4.</b> Take measurement, export data, & upload."
    end
    get_flow_cytometer_software(flow_cytometer: flow_cytometer)
    return flow_cytometer
  end
  

  ##TODO This is where you can add new cytometers
  # Using the instance of class FlowCytometer, we can determine which software module to import
  def get_flow_cytometer_software(flow_cytometer:)
    case flow_cytometer.type
    when 'BD Accuri C6'.to_sym
      Protocol.include(BDAccuri)
    when 'Attune'.to_sym
      Protocol.include(Attune)
    else
      raise "the #{flow_cytometer.type} flow cytometer in the #{lab_name} has no software steps associated to it, create a module with steps to use flow cytomter".upcase
    end
  end
  
  # Overrides method found in HighThroughputHelper, so that only ALLOWABLE_FC_SAMPLETYPES are transferred to a new collection
  def copy_sample_matrix(from_collection:, to_collection:)
    sample_hash = Hash.new()
    from_collection_sample_types = from_collection.matrix.flatten.uniq.reject{|i| i == EMPTY }.map {|sample_id| [sample_id, Sample.find(sample_id)] }
    from_collection_sample_types.each {|sid, sample| (ALLOWABLE_FC_SAMPLETYPES.include? sample.sample_type.name) ? (sample_hash[sid] = sample) : (sample_hash[sid] = EMPTY) }
    dilution_sample_matrix = from_collection.matrix.map {|row| row.map {|sample_id| sample_hash[sample_id] } }
    to_collection.matrix = dilution_sample_matrix
    to_collection.save()
  end
  
  # Overrides method found in HighThroughputHelper, so that only ALLOWABLE_FC_SAMPLETYPES are transferred to a new collection
  def part_provenance_transfer(from_collection:, to_collection:, process_name:)
    to_collection_part_matrix = to_collection.part_matrix
    from_collection.part_matrix.each_with_index do |row, r_i|
      row.each_with_index do |from_part, c_i|
        if !from_part.nil? || from_part 
          if ALLOWABLE_FC_SAMPLETYPES.include? from_part.sample.sample_type.name
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
  end

  # Guides technician to transfer the ALLOWABLE_FC_SAMPLETYPES wells to a flow cytometer valid container
  #
  # @effect Guides technician through transfer of cultures, then sets the collection to the output FieldValue
  def tech_transfer_to_valid_container(instrument:, output_fieldValue:)
    from_collection = collection_from(instrument.experimental_item); to_collection = collection_from(instrument.measurement_item)
    copy_sample_matrix(from_collection: from_collection, to_collection: to_collection)
    part_provenance_transfer(from_collection: from_collection, to_collection: to_collection, process_name: 'transfer')
    qty, units = get_container_working_volume(container=to_collection)
    display_coordinates = alpha_coordinates_96

    show do
      title "Transfer to Valid Container"
      separator
      note "Gather empty #{to_collection.object_type.name} #{to_collection}"
      note "Follow the table below to transfer only the shaded wells:"
      note "Transfer 200ul per well"
      bullet "<b>From</b> #{from_collection.object_type.name} #{from_collection}"
      table highlihgt_alpha_non_empty(from_collection)
      bullet "<b>To</b> #{to_collection.object_type.name} #{to_collection}"
      table highlight_non_empty(to_collection)
    end
    output_fieldValue.set(collection: to_collection)
  end
  
  # Finds a container's JSON parsable data association and grabs the working_vol association
  #
  # @param container [Item/Collection] is an item with a ObjectType.data association
  # @return qty [int] the number of units
  # @return units [string] the type of Units describing the working volume of the container
  def get_container_working_volume(container)
    working_volume = JSON.parse(container.object_type.data)['working_vol']
    raise "ObjectType #{container.object_type.name} does not have a JSON parsable <b>'working_vol'</b> association.
    Please go to containers and add an association" if working_volume.nil?
    qty = working_volume.split('_')[0].to_f
    units = working_volume.split('_')[1].to_s
    return qty, units
  end

  # Associate all `uploads` to the `target` DataAssociator. The keys of each upload will be
  # the concatenation of `key_name` and that upload's id.
  # Associating fcs files to the plan and operation makes fcs data of any specific well
  # easily accessible to users
  #
  # @param [String] key_name  the name which describes this upload set
  # @param [Plan] plan  the plan that the uploads will be associated to
  # @param [Array<Upload>] uploads  An Array containing several Uploads
  # @effects  associates all the given uploads to `plan`, each with a
  #         unique key generated from the combining `keyname` and upload id
  def associate_fcs_uploads(key_name, target, uploads)
    if target
      associations = AssociationMap.new(target)
      uploads.each do |up|
        associations.put("U#{up.id}_#{key_name}", up)
      end
      associations.save
    end
  end
    
  # Associate a matrix containing all `uploads` to `collection`.
  # The upload matrix will map exactly to the sample matrix of
  # `collection`, and it will be associated to `collection` as a value
  # of `key_name`
  #
  # @param [String] key_name  the key that the upload matrix will
  #           be associated under
  # @param [Collection] collection  what the upload matrix will be
  #           associated to
  # @param [Array<Upload>] uploads  An Array containing several Uploads
  # @effects  associates all the given uploads to `collection` as a 2D array inside a singleton hash
  def associate_uploads_to_plate(key_name:, collection:, uploads:)
    ot = collection.object_type
    uploads_well_matrix = Array.new(ot.rows) { Array.new(ot.columns) { EMPTY } }
    uploads.each do |up|
      alpha_coord = up.name[0..2]
      r_i, c_i = get_rc_from_alpha_coords(alpha_coord: alpha_coord)
      uploads_well_matrix[r_i][c_i] = up.id
    end
    collection_associations = AssociationMap.new(collection)
    # ensure we aren't overwriting an existing association
    unless collection_associations.get(key_name).nil?
      i = 0
      i += 1 until collection_associations.get("#{key_name}_#{i}").nil?
      key_name = "#{key_name}_#{i}"
    end
    collection_associations.put(key_name, {'upload_matrix' => uploads_well_matrix })
    collection_associations.save
  end
  
  # Process and associates the array of flow cytometry uploads to operation, plan, and the collection that was measured.
  def process_and_associate_data(instrument:, op:)
    measurement_args = instrument.measurement_data
    uploads = measurement_args[:uploads]
    associate_fcs_uploads(key_name=SAMPLE_UPLOAD_KEY, target=op, uploads=uploads)
    associate_fcs_uploads(key_name=SAMPLE_UPLOAD_KEY, target=op.plan, uploads=uploads)
    associate_uploads_to_plate(key_name: SAMPLE_UPLOAD_KEY.pluralize, collection: measurement_args[:mitem], uploads: uploads)
  end
  
  # Determines whether to keep plate based on user input
  def keep_transfer_plate(instrument:, user_val:)
    instrument.measurement_item.location = ((user_val.upcase == 'YES') ? 'Bench' : 'deleted')
  end
  
  # Cleans up technician workspace by releasing inputs and outputs
  def cleaning_up(release_arr=[])
    clean_up_inputs(release_arr)
    clean_up_outputs
  end

  # Cleanup input items
  #
  # @param release_arr [array] is an array of items that are found in Aq
  def clean_up_inputs(release_arr)
    operations.store(opts = { interactive: true, method: 'boxes', errored: false, io: 'input' })
    release release_arr, interactive: true
  end

  # Cleanup output items
  def clean_up_outputs()
    show do
      title "Cleaning Up"
      separator
      note "Return any remaining reagents used and clean bench"
    end
  end
end # module FlowCytometryHelper