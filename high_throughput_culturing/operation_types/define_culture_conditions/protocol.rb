class Protocol

  def main

    operations.each do |op|
        op.error("Control block error", "Control blocks are not intended to be run by a technician.") 
    end
    
  end

end
