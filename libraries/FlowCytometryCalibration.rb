needs "High Throughput Culturing/FlowCytometryHelper"
module FlowCytometryCalibration
  include AssociationManagement
  
  BEAD_SAMPLE_KEY = 'BEAD_UPLOAD'.freeze
  
  # Defines class FlowCytometry instance variables experimental_item and the measurement_item when measuring calibration beads on the flow cytometer
  #
  # @param flow_cytometer [class instance] instance of the flow cytometer
  # @param bead_item [Item] is the item from the input FieldValue of the Flow Cytometer Calibration
  def setup_calibration_measurement(flow_cytometer:, bead_item:)
    flow_cytometer.experimental_item = bead_item
    diluted_bead_items = bead_item.sample.items.reject {|item| item.location == 'deleted' || item.object_type.name == bead_item.object_type.name }
    if diluted_bead_items.empty?
      flow_cytometer.measurement_item = create_diluted_bead_item(bead_item)
    else
      flow_cytometer.measurement_item = diluted_bead_items[-1]
    end
  end
  
  # Generates a new virtual diluted bead item
  #
  # @param bead_item [Item] is the item from the input FieldValue of the Flow Cytometer Calibration
  # @return diluted_bead_item [Item] is a new Diluted bead item used for Calibration
  def create_diluted_bead_item(bead_item)
    diluted_bead_item = Item.new()
    diluted_bead_item.object_type = ObjectType.find_by_name('Diluted beads')
    diluted_bead_item.sample = bead_item.sample
    diluted_bead_item.quantity = 1
    diluted_bead_item.location = bead_item.location
    return diluted_bead_item
  end
  
  # Guides technician in preparing diluted beads from bead_item stock
  # 
  # @param flow_cytometer [class instance] instance of the flow cytometer
  def dilute_beads(flow_cytometer:)
    bead_item = flow_cytometer.experimental_item
    take [bead_item], interactive: true
    show do 
      title "Prepare #{bead_item.sample.name} #{bead_item} for Calibration"
      separator
      check "Grab a new, clean 1.5mL microfuge tube and label: <b>#{flow_cytometer.measurement_item}</b>"
      check "Next, add <b>1mL</b> of Molecular Grade H2O to the tube"
      check "Dispense a drop of each dropper found in the #{bead_item.sample.name} box (ie: Spherotech beads white cap & brown cap)."
      check "Vortex for 10 seconds"
      check "Spin down briefly"
    end
  end
  
  # Prepares calibration beads by determining whether current beads are reusable
  #
  # @param flow_cytometer [class instance] instance of the flow cytometer
  def prepare_calibration_beads(flow_cytometer:)
    if flow_cytometer.experimental_item.id == flow_cytometer.measurement_item.id
      take [flow_cytometer.measurement_item], interactive: true
      reuse_bead_item(flow_cytometer: flow_cytometer)
    else
      dilute_beads(flow_cytometer: flow_cytometer)
    end
  end
  
  # Deterimines if the beads are expired (>4weeks) or if there is not enough volume for the calibration
  # 
  # @param flow_cytometer [class instance] instance of the flow cytometer
  def reuse_bead_item(flow_cytometer:)
    if past_expiration?(flow_cytometer: flow_cytometer)
      flow_cytometer.measurement_item.mark_as_deleted
      diluted_bead_item = create_diluted_bead_item(flow_cytometer.experimental_item)
      flow_cytometer.measurement_item = diluted_bead_item
      dilute_beads(flow_cytometer: flow_cytometer)
    else
      respose = show do
        title 'Enough Volume to Continue?'
        separator
        note "Is there at least 0.5mL in #{flow_cytometer.measurement_item.object_type.name} #{flow_cytometer.measurement_item}?"
        select ['Yes','No'], var: 'response', label: "Is there at least 500ul?.", default: 0
      end
      if respose[:response] == 'Yes'
        flow_cytometer.measurement_item.mark_as_deleted
        diluted_bead_item = create_diluted_bead_item(flow_cytometer.experimental_item)
        flow_cytometer.measurement_item = diluted_bead_item
        dilute_beads(flow_cytometer: flow_cytometer)
      end
    end
  end
  
  # Determine if the beads are older than a month old
  def past_expiration?(flow_cytometer:)
    timepoint = Time.now()
    this_week = timepoint.strftime('%W').to_i
    expiration_week = flow_cytometer.measurement_item.week.to_i+5
    if this_week >= expiration_week
      return true
    else
      return false
    end
  end
  
  # Associate all `uploads` to the `target` DataAssociator. The keys of each upload will be
  # the concatenation of `key_name` and that upload's id.
  # Associating fcs files to the plan and operation makes fcs data of any specific well
  # easily accessible to users
  #
  # @param key_name [String] the name which describes this upload set
  # @param target [Aq Model] can be any Aq model class that can have associations
  # @param uploads [Array<Upload>] An Array containing several Uploads
  # @effects  associates all the given uploads to `plan`, each with a
  #         unique key generated from the combining `keyname` and upload id
  def associate_uploads(key_name, target, uploads)
    if target
      associations = AssociationMap.new(target)
      uploads.each do |up|
        associations.put("U#{up.id}_#{key_name}", up)
      end
      associations.save
    end
  end
  
  def process_and_associate_calibration(instrument:, ops:)
    calibration_measurement_upload = [instrument.measurement_data.fetch(:uploads).first]
    associate_uploads('BEADS_uploads', instrument.measurement_item, calibration_measurement_upload)
    ops.each do |op|
      associate_uploads(BEAD_SAMPLE_KEY, op, calibration_measurement_upload)
      associate_uploads(BEAD_SAMPLE_KEY, op.plan, calibration_measurement_upload)
    end
  end
  
end # module FlowCytometryCalibration