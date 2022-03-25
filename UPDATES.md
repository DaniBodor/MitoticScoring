Back to [home](https://github.com/DaniBodor/MitoticScoring)

## v1.4 - March 2022 - TrackMate integration
- Allow for option to use on TrackMate files without deleting TrackMate overlays

## v1.3 - March 2022 - Facilitate long-term tracking
- Allow for jumping back to t0 after each box (for long-term daughter tracking)
- Allow to not show box around each timepoint
- Print frame number of each time point in the waitwindow
- Allow typing show/hide to toggle displaying of ROIs
- Individual timepoints are now just called t0, t1, etc, rather than giving them specific names relating to mitosis
  - If you use this version to carry on with same experiment that was scored with previous version, there will now be new columns made for the timepoints. This should be easy to fix manually in excel or similar.
- Changed way settings from last time are stored and recalled
  - The current format avoids crashes or complicated workarounds each time settings are changed
  - This means that settings from previous version cannot be read and need to be re-set (but it should be future proof, which was the whole point of doing this)

## v1.26 - 27 Oct 2021
- Updates to observation list and options for mitotic stages, etc.

## v1.25 - 08 July 2021
- __Added python code to create XMLs from results table (for YOLO training)__
- Exporting image size to results table (needed for above)
- SubImage Extractor faster and bug fix for filenames with a space
- Bunch of minor edits and fixes


## v1.24 - 01 June 2021
- Column renaming for timepoint coordinates to clarify what it is
- Fixed bug when skipping each stage in the first entry of an experiment 
- Bunch of minor edits and fixes

## v1.21 - 28 May 2021 (PM)
- Allows for skipping drawing a box for a certain stage by typing 'skip' in the wait window
- Active observationlist is stored in FiJi.app folder, as are copies of previous defaults

## v1.20 - 28 May 2021 (AM)
- Numbering fixed for going back to a previously opened image
- Changing settings no longer creates a problem
  - Minor issue: additions to results table are at the end of table and not in order as expected

## v1.10 - 27 May 2021
- Fixed bug that deletes previous overlays (cell boxes) when closing and re-opening the same file
- Discontinued 'Click OK' mode, because it's not compatible with above and anyway the least useful mode
  - 'Click OK' is potentially more stable than other modes, so if people run into crashes a lot because of this I need to look back at it (not likely)
- Clarified window naming upon load custom observation list

## v1.0 - 26 May 2021
- Fixed bugs in 'Draw only' mode
- Fixed incorrect selection of 'Progress mode' from startup settings
- Stop 'Remove entry' from going nuts
- Hide ROI name that is in the way when observation list pops up
