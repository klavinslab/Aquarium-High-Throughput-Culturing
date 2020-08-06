def precondition(_op)
  if _op.input('require calibration?').value.downcase == 'yes'
    calibration_operation_type = OperationType.find_by_name("Flow Cytometry Calibration")
    calibration_op = _op.plan.operations.find { |op| op.operation_type_id == calibration_operation_type.id}
    if calibration_op.nil?
      _op.associate('Waiting for Calibration','In order to use Cytometer, `Cytometer Bead Calibration` must be run in the same plan')
      return false
    elsif calibration_op.status != 'done'
      _op.associate("Waiting for Calibration","Flow Cytometry cannot begin until Cytometer Calibration completes.")
      return false
    else
      _op.get_association('Waiting for Calibration').delete if _op.get_association('Waiting for Calibration')
      return true
    end
  else
    return true
  end
end