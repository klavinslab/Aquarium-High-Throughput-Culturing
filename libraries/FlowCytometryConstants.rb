
# Flow Cytometry Constants 
ALLOWABLE_FC_SAMPLETYPES = ["Plasmid", "Yeast Strain", "E coli strain"].freeze # Cultures
SAMPLE_UPLOAD_KEY = 'SAMPLE_UPLOAD'.freeze
BEAD_UPLOAD_KEY = 'BEAD_UPLOAD'.freeze

# Flow Cytometry instance constants
KLAVINS_LAB = 'Haase Lab'.to_sym #'Klavins Lab'.to_sym
HAASE_LAB = 'Haase Lab'.to_sym
FLOW_CYTOMETER_TYPE = {'Klavins Lab':'BD Accuri C6'.to_sym,'Haase Lab':'Attune'.to_sym}
MY_FLOW_CYTOMETER_PROPERTIES = {
  'Klavins Lab': {
    'BD Accuri C6': {
      software_properties: {
        sample_type_settings: {
          'Yeast Strain': {'Run Volume': 'xxxx', 'Flow Rate': 'xxxx', 'Stop Option': 'Stop on 10,000 events (all events)'},
          'Plasmid': {'Run Volume': 'xxxx', 'Flow Rate': 'xxxx', 'Stop Option': 'Stop on 10,000 events (all events)'},
          'Beads': {'Run Volume': 'xxxx', 'Flow Rate': 'xxxx', 'Stop Option': 'Stop on 10,000 events (all events)'}
        },
        plate_type_hash: {
          '96 Well Flat Bottom (black)': 'Flat bottom plate',
          'Diluted beads': '24-Well Tube Rack'
        },
        images: {
          open_software: "Actions/Yeast_Gates/flowCytometryImages/open_FC_software_icon.png",
          select_plate_type: "Actions/Yeast_Gates/flowCytometryImages/select_plate_type.png",
          apply_settings: "Actions/Yeast_Gates/flowCytometryImages/flow_cytometry_settings.png",
          read_plate: "Actions/Yeast_Gates/flowCytometryImages/measure_plate_autorun.png",
          export_new_data: "Actions/FlowCytometry/saveFCS_menu_cropped.png",
          new_export_directory: "Actions/FlowCytometry/saveFCS_dirname_cropped.png"
        },
        measurement_type_templates: {
          "cleaning": {dtype: 'could be the three cleaning files to record contamination over time!'},
          "Yeast": {dtype: "paratmers for yeast measurements"},
          "Ecoli": {},
          "Calibration": {}
        },
        saving_directory: 'FIND_OUT_THE_PATH/FCS_Exports'
      },
    valid_containers: ['96 Well Flat Bottom (black)'],
    },
  },
  'YOUR_LAB_HERE':{
    'YOUR_PLATE_READER_TYPE':{ 
      software_steps: 'properties', 
      valid_containers: ['96 Well Flat Bottom (black)'], 
    },
    saving_directory: 'SAVING_DIRECTORY'
  },
  'Haase Lab': {
    'Attune': {
      software_properties: {
        sample_type_settings: {
          'Yeast Strain': {'Run Limits': '30,000 events', 'Run Limits (Max Volume)': '250ul', 'Fluidics': 'Fast', 'Set Threshold': 'FSC-H less than 400,000'},
          'Plasmid': {'Run Limits': '30,000 events', 'Run Limits (Max Volume)': '250ul', 'Fluidics': 'Fast', 'Set Threshold': 'FSC-H less than 80,000'},
          'Beads': {'Figure out': 'Calibration limits','Run Limits': '30,000 events', 'Run Limits (Max Volume)': '250ul', 'Fluidics': 'Fast', 'Set Threshold': 'FSC-H less than 80,000'}
        },
        plate_type_hash: {
          '24 Unit Disorganized Collection': 'Disorganized Collection',
          'Diluted beads': '24-Well Tube Rack'
        },
        images: {
          open_software: "Actions/Yeast_Gates/flowCytometryImages/open_FC_software_icon.png",
          select_plate_type: "Actions/Yeast_Gates/flowCytometryImages/select_plate_type.png",
          apply_settings: "Actions/Yeast_Gates/flowCytometryImages/flow_cytometry_settings.png",
          read_plate: "Actions/Yeast_Gates/flowCytometryImages/measure_plate_autorun.png",
          export_new_data: "Actions/FlowCytometry/saveFCS_menu_cropped.png",
          new_export_directory: "Actions/FlowCytometry/saveFCS_dirname_cropped.png"
        },
        measurement_type_templates: {
          "cleaning": {dtype: 'could be the three cleaning files to record contamination over time!'},
          "Yeast": {dtype: "paratmers for yeast measurements"},
          "Ecoli": {},
          "Calibration": {}
        },
        saving_directory: 'FIND_OUT_THE_PATH/FCS_Exports'
      },
    valid_containers: ['24 Unit Disorganized Collection'],
    },
  },
  'YOUR_LAB_HERE':{
    'YOUR_PLATE_READER_TYPE':{ 
      software_steps: 'properties', 
      valid_containers: ['96 Well Flat Bottom (black)'], 
    },
    saving_directory: 'SAVING_DIRECTORY'
  }
}
