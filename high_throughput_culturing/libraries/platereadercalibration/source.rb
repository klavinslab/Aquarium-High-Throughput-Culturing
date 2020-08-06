module PlateReaderCalibration
  include Units, Debug, AssociationManagement
  # Constants
  DILUTANT_VOL = 100 # Final vol that each flourescence cal well will have
  FLOUR_ALIQUOT_CONC = 50#uM # The starting concentration of the flour std curve
  
  # Prepare iGEM plate reader calibration plate
  def prep_calibration_plate(pr, ops, out_fv_str, flour_item, optical_item)
    new_mtype = true  
    create_a_new_cal_plt, reusable_plate_item = check_for_reusable_plate(ops.running.map {|op| op.operation_type}.uniq.first)
    create_a_new_cal_plt ? ops.make : reusable_plate_item
    additional_solutions = create_a_new_cal_plt ? [get_pbs_item, get_water_item] : []
    ops.each do |op|
      create_a_new_cal_plt ? op.output(out_fv_str).item : op.output(out_fv_str).set(opts={item: reusable_plate_item})
      pr.setup_experimental_measurement(experimental_item: op.output(out_fv_str).item, output_fv: op.output(out_fv_str))
      new_mtype = setup_plate_reader_software_env(pr: pr, new_mtype: new_mtype)
      # Materials based on whether a new calibration plate will be filled
      take_items       = create_a_new_cal_plt ? [flour_item, optical_item].concat(additional_solutions) : [pr.measurement_item]
      new_materials    = create_a_new_cal_plt ? ['P1000 Multichannel', 'P200 Pipette'] : ['P20 Multichannel']
      empty_containers = create_a_new_cal_plt ? [pr.measurement_item] : []
      gather_materials(empty_containers: empty_containers, new_materials: new_materials, take_items: take_items)
      if create_a_new_cal_plt # then fill empty container and add inputs to op
        tech_fill_calibration_plate(calibration_plate: pr.measurement_item, water_item: get_water_item, flour_item: flour_item, optical_item: optical_item)
        # additional_solutions.each {|item| add_solution_to_op(op: op, fv_str: "#{item.sample.name} Aliquot", item: item) }
        op.operation_type.associate(:calibration_plate, {date_created: todays_date, item_id: pr.measurement_item.id})
      else # reuse the unexpired calibration plate
        equilibrate_calibration_plate(op: op, calibration_solutions: calibration_solutions)
      end
    end
    return new_mtype
  end
  
  # Check to see if there are any calibration plates that are not older than a month
  def check_for_reusable_plate(op_type)
    create_a_new_cal_plt = true
    calibration_plate = nil # if the plate is less than a month old use the cal plate
    op_type.data_associations.select {|da| da[:key] == :calibration_plate }.map do |da|
      key, ot_obj = da[:key], da[:object]
      obj = ot_obj[key]
      date_created, present, plus_month = obj[:date_created], todays_date, [date_created[0..1], date_created[2..3], date_created[4..7]].map {|i| i.to_i}
      plus_month[0] = plus_month[0] + 1
      date_created = [date_created[0..1], date_created[2..3], date_created[4..7]].map {|i| i.to_i}
      if date_created[0] == plus_month[0] # Checking month
        if plus_month[1] >= date_created[1] # Checking day
          create_a_new_cal_plt = true
          expired_plate = Item.find(obj[:item_id])
          show {check "Before creating a new Calibration plate, throw away the expired plate #{expired_plate} found at #{expired_plate.location}"}
          expired_plate.mark_as_deleted
        else
          calibration_plate = Item.find(obj[:item_id])
          create_a_new_cal_plt = false
        end
      else
        calibration_plate = Item.find(obj[:item_id])
        create_a_new_cal_plt = false
      end
    end
    return create_a_new_cal_plt, calibration_plate
  end
  
  # Techician retrieves reused calibration plate and equilibrates it to room temperature before measuring
  def equilibrate_calibration_plate(op:, calibration_solutions:)
    plate = op.outputs[0].collection
    cs_wells = get_calibration_solution_wells(calibration_solutions: calibration_solutions, collection: plate)
    show do
      title "Equilibrating Calibration Plate #{plate}"
      separator
      check "Let the #{plate} plate sit at room temperature (25#{DEGREES_C}) for 10 minutes to avoid condensation skewing the calibration."
      note "<b>After the timer is up:</b>"
      note "Using a multichannel pipette, resuspend the highlighted wells:"  
      table highlight_alpha_rc(collection_from(plate), cs_wells[op.input("Optical Particles").sample.name])
      check "Use a kimwipe to remove condensation from the top and bottom of the plate."
    end
  end
  
  # Generate a hash describing which [r,c] a given sample is in, used for displaying
  def get_calibration_solution_wells(calibration_solutions:, collection:)
    cs_wells = {}
    calibration_solutions.map {|i| cs_wells[i.sample.name] = get_sample_wells(collection: collection, sample: i.sample) }
    return cs_wells
  end
  
  def get_pbs_item
    get_pbs_sample.items.select {|i| i.location != 'deleted' }[0]
  end
  
  def get_pbs_sample
    Sample.find_by_name('PBS')
  end
  
  def get_water_item
    get_water_sample.items.select {|i| i.location != 'deleted' }[0]
  end
  
  def get_water_sample
    h2o_type = "Nuclease-free water" # Change in Production Aq to Mol grade H2O
    h2o_samp = Sample.find_by_name(h2o_type)
  end
  
  def get_stock_solution_concentration(ot:)
    name = ot.name.split(' ')[0]
    units = name[-2..-1]
    stock_conc = name.match /(?<conc>\d+)/
    return stock_conc[:conc].to_i, units
  end
    
  def dilute_flourescence_item(flour_item:)
    flour_ot = ObjectType.find(flour_item.object_type_id)
    conc, units = get_stock_solution_concentration(ot: flour_ot)
    case units
    when MILLIMOLAR
      dilution_factor = ((conc*1000) / FLOUR_ALIQUOT_CONC)
    when MICROMOLAR
      dilution_factor = (conc*100)/FLOUR_ALIQUOT_CONC
    else
      raise "The current flourescence #{flour_ot} does not contain information about the concentration. 
      please create a new container that will have a name with the concentraiton of the reagent".upcase
    end
    flour_stk_vol = 1000/dilution_factor
    pbs_vol = 1000 - flour_stk_vol
    show do
      title "Dilute #{flour_item} #{flour_item.sample.name}"
      separator
      note "Vortex item #{flour_item.id} #{flour_ot.name} and make sure there are no precipitates."
      check "In a fresh 1.5mL Eppendorf tube, dilute #{flour_stk_vol}#{MICROLITERS} of  #{flour_ot.name} into #{pbs_vol}#{MICROLITERS} of 1X PBS - Final Concentration [#{FLOUR_ALIQUOT_CONC}#{MICROMOLAR}]"
      note "Make sure to vortex."
    end
  end
  
  # Set iGEM fluorecein salt dilutions, ludox aliquots, and water aliquots to their template location in the calibration plate
  def set_calibration_plate_sample_matrix(calibration_plate:, flour_item:, water_item:, optical_item:)
    calibration_plate = collection_from(calibration_plate)
    rows, cols = calibration_plate.object_type.rows, calibration_plate.object_type.columns
    new_matrix = Array.new(rows) { Array.new(cols) { -1 } }
    rows.times do |r|
     cols.times do |c|
        if r < 4
         new_matrix[r][c] = flour_item.sample.id 
        elsif r == 4
         new_matrix[r][c] = optical_item.sample.id
        elsif r == 5
          new_matrix[r][c] = water_item.sample.id
        end
      end
    end
    calibration_plate.matrix = new_matrix
    calibration_plate.save
    return calibration_plate
  end
  
  # Guide tech to fill a new calibration plate with fresh calibration solutions
  def tech_fill_calibration_plate(calibration_plate:, flour_item:, water_item:, optical_item:)
    dilute_flourescence_item(flour_item: flour_item)
    set_calibration_plate_sample_matrix(calibration_plate: calibration_plate, flour_item: flour_item, water_item: water_item, optical_item: optical_item)
    flourescence_serial_dilution(calibration_plate: calibration_plate, flour_item: flour_item)
    [optical_item, water_item].each {|i| fill_calibration_plate_with_optical_solution(calibration_plate: calibration_plate, solution_item: i)}
    # Create associations if a new calibration plate is made and filled
    associate_data(object=calibration_plate, key="calibration_plate", data = {date_created: todays_date}, opts = {})
  end
  
  # Guide tech through creating a fluorecein salt serial dilution
  def flourescence_serial_dilution(calibration_plate:, flour_item:) # iGEM Protocol 2018
    dilutant_wells = collection_from(calibration_plate).select {|well| well == flour_item.sample.id }.select {|r,c| c != 0}
    # direct tech to fill new calibration plate
    show do
      title "Creating a New #{calibration_plate} Calibration Plate"
      separator
      note "You will need <b>#{(dilutant_wells.length * 0.1) + 0.1}mL</b> of 1X PBS for the next step."
      note "Follow the table below to dispense 1X PBS in the appropriate wells:"
      table highlight_rc(calibration_plate, dilutant_wells) {|r,c| "#{DILUTANT_VOL}#{MICROLITERS}"}
    end
    flour_serial_image = "Actions/Yeast_Gates/plateReaderImages/flour_serial_dilution.png"
    show do
      title "Serial Dilution of #{flour_item} #{flour_item.sample.name}"
      separator
      note "From the #{FLOUR_ALIQUOT_CONC}#{MICROMOLAR} #{flour_item.sample.name} solution, dispense <b>#{DILUTANT_VOL+DILUTANT_VOL}#{MICROLITERS}</b> in wells <b>A1, B1, C1, D1</b>"
      note "Following the image below, transfer <b>#{DILUTANT_VOL}#{MICROLITERS}</b> of #{FLOUR_ALIQUOT_CONC}#{MICROMOLAR} #{flour_item.sample.name} solution in Column 1 to Column 2"
      note "Resuspend by pipetting up and down 3X"
      note "Repeat until column 11 and discard the remaining <b>#{DILUTANT_VOL}#{MICROLITERS}</b>."
      image flour_serial_image
    end
  end
  
  # Guide tech through filling calibration plate with ludox optical particle solution
  def fill_calibration_plate_with_optical_solution(calibration_plate:, solution_item:)
    plate = collection_from(calibration_plate)
    rc_list = plate.select {|well| well == solution_item.sample.id}
    show do
      title "Filling #{calibration_plate} Calibration Plate"
      separator
      note "Follow the table below to dispense <b>#{solution_item.sample.name}</b> into the appropriate wells."
      table highlight_rc(plate, rc_list) {|r,c| optical_solution_vol(r, c)}
    end
  end
  
  # Determine how much volume of solution is required for a given column
  def optical_solution_vol(row, col)
    if col < 4
      return "#{100}#{MICROLITERS}"
    elsif col.between?(4, 7)
      return "#{200}#{MICROLITERS}"
    else col.between?(7, 11)
      return "#{300}#{MICROLITERS}"
    end
  end
    
  def todays_date
    DateTime.now.strftime("%m%d%Y")
  end
  
  # The plotted result of this method can be fit to a curve
  # to be used for calibrating the plate reader. This is very specific to the
  # Eriberto's calibration of the biotek plate reader.
  #
  # @param upload [Upload]  the object whihc can be resolved to calibration csv
  # @return [Hash]  a hash containing averaged measurements for
  #  					every concentration and volume tested
  #
  #
  #
  # New Description needed - some refactoring may be necessary, but works! 
  def get_calibration_hash(dm:, measurement_type:)
    result = {}
    data_by_conc = Hash.new { |h, key| h[key] = [0, 0] }
    case measurement_type
    when :Calibration_Green_Fluorescence
      starting_concentration = 50.0#uM
      # first 4 rows are serial dilutions
      for i in 0...4
        12.times do |j|
          if j == 11
            this_conc = 0
          else
            # each column is a 2x dilution of the previous, starting at 50uM
            this_conc = starting_concentration / (2**j)
          end
          data = data_by_conc[this_conc]
          data[0] += dm[i][j].to_f
          data[1] += 1
          data_by_conc[this_conc] = data
        end
      end
      # add serial dilution averages to result hash
      data_by_conc.each_key do |k|
        data = data_by_conc[k]
        result[k] = data[0] / data[1]
      end
    when :Calibration_Optical_Density
      # row 5, 6 are lud dilutions and pure solution respectively
      for i in 4...6
        for j in 0...4
          data_by_conc["100_#{i}"][0] += dm[i][j].to_f
          data_by_conc["100_#{i}"][1] += 1
        end
        for j in 4...8
          data_by_conc["200_#{i}"][0] += dm[i][j].to_f
          data_by_conc["200_#{i}"][1] += 1
        end
        for j in 8...12
          data_by_conc["300_#{i}"][0] += dm[i][j].to_f
          data_by_conc["300_#{i}"][1] += 1
        end
      end
      # add lud averages to result hash
      for i in 1..3
        lud_avg = data_by_conc["#{i}00_4"][0] / data_by_conc["#{i}00_4"][1]
        sol_avg = data_by_conc["#{i}00_5"][0] / data_by_conc["#{i}00_5"][1]
        result["#{i}00"] = (lud_avg - sol_avg).round(5) # Returns blanked averages
      end
    end
    return result
  end
  
  # This function creates a standard curve from the flourocein calibration plate
  #
  # @param coordinates [hash or 2D-Array] can be a hash or [[x,y],..] where x is known concentration & y is measurement of flouroscence
  #
  # @returns slope [float] float representing the slope of the regressional line
  # @returns yint [float] float representing where the line intercepts the y-axis
  # @returns x_arr [Array] a 1D array for all x coords
  # @returns y_arr [Array] a 1D arrya for all y coords
  def standard_curve(coordinates:)
    # Calculating Std Curve for GFP
    num_of_pts, a, x_sum, y_sum, x_sq_sum = 0, 0, 0, 0, 0
    x_arr, y_arr = [], []
    coordinates.each do |x, y|
      if x < 25 # Above 25uM is out of linear range of our instrument
        a += (x*y)
        x_sum += x
        x_sq_sum += (x**2)
        y_sum += y
        x_arr.push(x)
        y_arr.push(y)
        num_of_pts += 1
      end
    end
    a *= num_of_pts
    b = x_sum * y_sum
    c = num_of_pts * x_sq_sum
    d = x_sum**2
    slope = (a - b)/(c - d)
    f = slope * (x_sum)
    yint = (y_sum - f)/num_of_pts
    # show{note "y = #{(slope).round(2)}x + #{(yint).round(2)}"}
    return (slope).round(3), (yint).round(3), x_arr, y_arr
  end  
  
  # This function calculates how much deviation points are from a regressional line - R-squared Value 
  # The closer it is to 1 or -1 the less deviation theres is
  #
  # @param slope [float] float representing the slope of the regressional line
  # @param yint [float] float representing where the line intercepts the y-axis
  # @param x_arr [Array] a 1D array for all x coords
  # @param y_arr [Array] a 1D arrya for all y coords
  #
  # @returns rsq_val [float] float representing the R-squared Value
  def r_squared_val(slope, yint, x_arr, y_arr)
    y_mean = y_arr.sum/y_arr.length.to_f
    # Deviation of y coordinate from the y_mean
    y_mean_devs = y_arr.map {|y| (y - y_mean)**2}
    dist_mean = y_mean_devs.sum # the sq distance from the mean
    # Finding y-hat using regression line
    y_estimate_vals = x_arr.map {|x| (slope * x) + yint }
    # Deviation of y-hat values from the y_mean
    y_estimate_dev = y_estimate_vals.map {|y| (y - y_mean)**2}
    dist_regres = y_estimate_dev.sum # the sq distance from regress. line
    rsq_val = (dist_regres/dist_mean).round(4)
    return rsq_val
  end
  
  def get_trendline_equation(coordinates_hash:)
    slope, yint, x_arr, y_arr = standard_curve(coordinates: coordinates_hash)
    r_sq = r_squared_val(slope, yint, x_arr, y_arr)
    trendline = "y = #{slope}x + #{yint}  (R^2 = #{r_sq})"
    return trendline
  end
  
  # This fuction uses a reference od600 measurement to calculate the correction factor for different vols (100ul, 200, 300)
  # 
  # @param hash [hash] is the hash of averaged blanked LUDOX samples at different volumes
  # @returns correction_val_hash [hash] is the hash containing the correction factor for the optical density (600nm) for this experiment
  def optical_correction_factors(hash)
    ref_od600 = 0.0425 #Taken from iGEM protocol - is the ref val of another spectrophotometer
    # ref/corrected vals
    correction_val_hash = Hash.new()
    hash.each do |vol, ave|
      correction_val_hash[vol[3..6]] = (ref_od600/ave).round(4)
    end
    return correction_val_hash
  end

  def get_calibration_calculated_values(cal_hash:, measurement_type:)
    case measurement_type
    when :Calibration_Green_Fluorescence
      return get_trendline_equation(coordinates_hash: cal_hash)
    when :Calibration_Optical_Density
      return optical_correction_factors(cal_hash)
    else
      raise "this #{measurement_type} measurement type is not recognized as a calibration measurement"
    end
  end
  
end # module PlateReaderCalibration