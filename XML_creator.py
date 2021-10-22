# -*- coding: utf-8 -*-
"""
Created on Tue Jun 29 16:00:13 2021

@author: dani
"""

##### DEVELOPMENT NOTE
# think about how to deal with cells with multiple problems:
#   - create separate label for each combination OR label same cell multiple times, once for each problem OR some mix of the two
#   - think about 'dominance' of label_list. If a certain label causes/obliges another, maybe only label with top label?
#   - create tkinter tool for GUI feedback on this
#   - create mode to select from multiple



import pandas as pd
import xml.etree.ElementTree as ET # modeled after: https://openwritings.net/pg/python/python-how-write-xml-file
from xml.dom import minidom
import os


#%% SETTINGS

# Data import/export
directory = './output/YOLO/'
csv_name = 'MitoticStages_Scoring_bin'  #CSV from scoring macro
limit_movies = '' # movie name or list of movie names to include (empty/False means include all)
tp_used = 0 # timepoint to use for training
project_name = 'my-project-name'
unlabeled = 'Normal' # label for cells that have no other marks
tag_by = 'dropdown' # dropdown OR checkmark

# Naming of indivisual stills
extension = 'png'       # file extension without the dot
filenaming_digits = 4   # how many digits are used in numbering (FiJi default is 4)


# create libraries to select subset of all events.
#subset_include = {'Mitotic_Stage': ['Anaphase']}
#subset_exclude = {'Mitotic_Stage': ['Telophase']}
subset_include = {}
subset_exclude = {}

# list columns to drop from dataframe)
drop_columns = ['New_Cell']


# processes to run through in code
load_new_data = 1
save_df = 1
do_XML = 1
export = 1


#%% PRELIMINARIES


inData = directory + csv_name +'.csv' #CSV from scoring macro
if inData.endswith('.csv.csv'):
    inData = inData[:-4]
xmldir = directory + csv_name + '_Annotations/'


# list of headers to remove from label_list
non_data_headers = ['movie','event#','extract_code', 'highlight', 'highlight_note', 'still_image', 'image_size']

# lists using for looping
Unspecified = ['pose','truncated','difficult']
coord_labels = ['xmin','ymin','xmax','ymax']

# variables for recurring stuff
tp_used = 't' + str(tp_used)
coord_prefix = tp_used + '_'
coord_suffix = '_(Xmin_Ymin_Xmax_Ymax_T_Z)'

labeled = 'non-' + unlabeled


#%% LOAD DATA FROM CSV

if load_new_data:
    # read CSV
    df = pd.read_csv(inData)
    df = df.drop(df.columns[0], axis=1)
    
    # drop some movies from df
    if limit_movies:
        if type(limit_movies) == str:
            limit_movies = [limit_movies]
        df = df[df['movie'].isin(limit_movies) == True]
    
    # create subset of all data to analyze
    for col in subset_include:
        indexNames = df[~df[col].isin(subset_include[col])].index
        df = df.drop(indexNames).reset_index(drop=True)
        print(f'keep data: {col} - {subset_include[col]}')
    
    for col in subset_exclude:
        indexNames = df[df[col].isin(subset_exclude[col])].index
        df = df.drop(indexNames).reset_index(drop=True)
        print(f'remove data : {col} - {subset_exclude[col]}')
    
    # remove all empty columns and any columns listed at beginning
    df = df.loc[:, (df != 0).any(axis=0)].dropna(axis=1, how='all')
    for col in drop_columns:
        try:
            df.drop(col, axis=1, inplace = True)
        except KeyError:
            print(col + ' not found in df, proceed without dropping')
        
    # get list of all potential labels
    label_list = list(df.columns)
    label_list = [c for c in label_list if c.lower() not in non_data_headers]             # removes default headers
    label_list = [c for c in label_list if not ( c.startswith('t') and c[1:].isdigit() )] # removes timepoint headers
    label_list = [c for c in label_list if not c.endswith(coord_suffix)]                  # removes coordinate headers
    label_list = [c for c in label_list if not c.lower().startswith('note') ]             # removes notes columns

    # add column for still name
    df['still_image'] = df['movie'].str[:-4]
    df['still_image'] = df['still_image'] + df[tp_used].map(str).apply(lambda x: x.zfill(filenaming_digits))
    df['still_image'] = df['still_image'] + '.' + extension

    # add column for total events found and column for no other events
    df.insert(3,labeled,df[label_list].sum(axis=1))
    df.insert(3, unlabeled, (df[labeled] == 0).astype(int) )
    label_list = [unlabeled] + label_list
    
    # get total numbers for each label
    counter = df.groupby('movie').sum()
    counter = counter.drop(['event#',tp_used], axis = 1) # this needs to be made so that it drops all tp data
    counter = counter.loc[:, (counter != 0).any(axis=0)]
    counter['Events'] = df.groupby('movie')['event#'].count()
    if len(counter > 1):
        counter.loc['Total',:]= counter.sum(axis=0)

    # get name of header used for defining coord
    coord_header = [x for x in list(df.columns) if (x.startswith(coord_prefix) and x.endswith(coord_suffix) )][0]

    if save_df:
        try:
            df.to_csv(directory + 'XML_Dataframe_' + csv_name + '.csv')
        except PermissionError:
            print("no permission to save csv (probably becuase it's still open")
        
#%% FUNCTIONS FOR XML CREATION

def makeXML(im):

    # Create root element
    root = ET.Element("annotation")
     
    # Add file location elements
    ET.SubElement(root, 'folder'    ).text = project_name
    ET.SubElement(root, 'filename'  ).text = im
    ET.SubElement(root, 'path'      ).text = f'{project_name}/{im}'
    source = ET.SubElement(root, 'source')
    ET.SubElement(source, 'database').text = 'Unspecified'

    # Add elements for image size
    imsize = df.loc[df['still_image'] == im]['image_size'].iloc[0].split('x')
    size = ET.SubElement(root, 'size')
    ET.SubElement(size, 'width').text =  str(imsize[0])
    ET.SubElement(size, 'height').text = str(imsize[1])
    ET.SubElement(size, 'depth').text =  str(1)
    
    # run for each event on this frame
    for i, event in df.loc[df['still_image'] == im].iterrows():

#        # create label for otherwise unlabeled events
#        if sum(event[label_list]) == 0:
#            event[unlabeled] = 1
        
        # Add element for each label of event
        for label in label_list:
            if event[label] == 1:
                obj = ET.SubElement(root, 'object')
                ET.SubElement(obj, 'name').text = label
                for group in Unspecified:
                    ET.SubElement(obj, group).text = 'Unspecified'
                BoundingBox(event, obj) # defined below

    # Write XML file
    if export:
        if not os.path.exists(xmldir):
            os.mkdir (xmldir)

        xmlstr = minidom.parseString(ET.tostring(root)).toprettyxml(indent="   ") 
        with open(xmldir + im[:-3] + "xml", "w") as f:
            f.write(xmlstr) 


def BoundingBox(row, parent):
    # get image coordinates of event
    coordinates = row[coord_header].split('_')
    
    # create bounding element with subelements for the coordinates
    bndbox = ET.SubElement(parent, 'bndbox')
    for i, c in enumerate(coord_labels):
        ET.SubElement(bndbox, c).text = coordinates[i]



#%% LOOP THROUGH ALL MOVIES IN CSV AND CREATE 1 XML FILE PER IMAGE (THAT HAS >0 EVENTS)

if do_XML:
    # create output folder
    
    for im in df['still_image'].unique():
        makeXML(im)




