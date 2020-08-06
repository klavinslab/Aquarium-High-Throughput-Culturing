# Change LAB_NAME to use different plate reader constants
LAB_NAME = 'Klavins Lab'.to_sym
YOUR_LAB_NAME = 'YOUR_LAB_HERE'.to_sym
PLATE_READER_TYPE = {'Klavins Lab':'Gen 5 BioTek'.to_sym,'YOUR_LAB_HERE':'YOUR_PLATE_READER_TYPE'.to_sym}

MY_PLATE_READER_PROPERTIES = {
  'Klavins Lab': {
    'Gen 5 BioTek': {
      software_properties: {
        images: {
          open_software: "Actions/Yeast_Gates/plateReaderImages/open_biotek.PNG",
          read_plate: "Actions/Yeast_Gates/plateReaderImages/begin_plate_reader.PNG",
          export_new_data: "Actions/Yeast_Gates/plateReaderImages/exporting_data_new.GIF",
          export_data_button: "Actions/Yeast_Gates/plateReaderImages/excel_export_button_new.png",
          save_export: "Actions/Yeast_Gates/plateReaderImages/saving_export_csv_new.png"
        },
        export_mesurement_type: { 
            "Optical Density":    {dtype: 'Read 1:600'},           # Change the template to not blank the measurement data uploaded and exported
            "Green Fluorescence": {dtype: 'Read 2:485/20,516/20'},                   ## Since we are not sure where the blank samples will be, we can use Aq to determine the OD of the 
            'Calibration Optical Density':    {dtype: 'Read 1:600'},                 ## blanking sample used and then use that to process the data when associating raw and true part item associations
            'Calibration Green Fluorescence': {dtype: 'Read 2:485/20,516/20'}
          },
        measurement_type_templates: {
          'Optical Density':'OD600_GFP_measurement',
          'Green Fluorescence':'OD600_GFP_measurement',
          'Optical Density & Green Fluorescence':'OD600_GFP_measurement',
          'Calibration':'calibration_template_v1',
          'Time Series':'create a new timeseries template'.upcase
        },
        saving_directory: 'FIND_OUT_THE_PATH/_UWBIOFAB'
      },
    valid_containers: ['96 Well Flat Bottom (black)', '24-Well TC Dish'],
    },
  },
  'YOUR_LAB_HERE':{
    'YOUR_PLATE_READER_TYPE':{ 
      software_steps: 'properties', 
      valid_containers: ['96 Well Flat Bottom (black)', '24-Well TC Dish'], 
    },
    saving_directory: 'SAVING_DIRECTORY'
  }
}
