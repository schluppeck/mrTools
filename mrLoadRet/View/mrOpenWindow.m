function view = mrOpenWindow(viewType,mrLastView)
%
%  view = openWindow(viewType)
%
% djh, 6/2004
%        $Id: mrOpenWindow.m 2838 2013-08-12 12:52:20Z julien $

if ieNotDefined('viewType'),viewType = 'Volume';end
% note we don't use ieNotDefined here, because
% if mrLastView is empty then the user doesn't
% want to ignore mrLastView
if ~exist('mrLastView','var')
  mrLastView = 'mrLastView.mat';
end

mrGlobals;

% startup a view
view = newView(viewType);

% view is empty if it failed to initialize
if ~isempty(view)
  fig = mrLoadRetGUI('viewNum',view.viewNum);
  set(fig,'CloseRequestFcn',@mrQuit);
  view = viewSet(view,'figure',fig);
else
  return
end
% set the location of the figure
figloc = mrGetFigLoc('mrLoadRetGUI');
if ~isempty(figloc)
  %deal with multiple monitors
  [whichMonitor,figloc]=getMonitorNumber(figloc,getMonitorPositions);
  set(fig,'Position',figloc);
end

set(fig,'Renderer','painters')
% set the keyoard accelerator
%mrAcceleratorKeys('init',view.viewNum);

% set the position of the main base viewer
gui = guidata(fig);
gui.marginSize = 0.01;
gui.anatPosition = [0.3 0.2+gui.marginSize 1-0.3-gui.marginSize 1-0.2-2*gui.marginSize];

% create 3 axis for display all three orientations at once
% set up the position of each of the 3 axis. Start them
% in an arbitrary position, being careful not to overlap
gui.sliceAxis(1) = subplot('Position',[0 0 0.01 0.01],'Parent',fig);
axis(gui.sliceAxis(1),'off');
set(gui.sliceAxis(1),'HandleVisibility','off');
gui.sliceAxis(2) = subplot('Position',[0.02 0 0.01 0.01],'Parent',fig);
axis(gui.sliceAxis(2),'off');
set(gui.sliceAxis(2),'HandleVisibility','off');
gui.sliceAxis(3) = subplot('Position',[0.02 0.02 0.01 0.01],'Parent',fig);
axis(gui.sliceAxis(3),'off');
set(gui.sliceAxis(3),'HandleVisibility','off');

% save the axis handles
guidata(fig,gui);

% add controls for multiAxis
mlrAdjustGUI(view,'add','control','axisSingle','style','radio','value',0,'position',  [0.152    0.725   0.1    0.025],'String','Single','Callback',@multiAxisCallback);
mlrAdjustGUI(view,'add','control','axisMulti','style','radio','value',0,'position',  [0.152    0.695   0.1    0.025],'String','Multi','Callback',@multiAxisCallback);
mlrAdjustGUI(view,'add','control','axis3D','style','radio','value',0,'position',  [0.152    0.665   0.1    0.025],'String','3D','Callback',@multiAxisCallback);

% Initialize the scan slider
nScans = viewGet(view,'nScans');
mlrGuiSet(view,'nScans',nScans);
mlrGuiSet(view,'scan',min(1,nScans));
% Initialize the slice slider
mlrGuiSet(view,'nSlices',0);
% init showROIs to all perimeter
view = viewSet(view,'showROIs','all perimeter');
view = viewSet(view,'labelROIs',1);


% Add plugins
if ~isempty(which('mlrPlugin')), view = mlrPlugin(view);end

baseLoaded = 0;
if ~isempty(mrLastView) && isfile(sprintf('%s.mat',stripext(mrLastView)))
  disppercent(-inf,sprintf('(mrOpenWindow) Loading %s',mrLastView));
  mrLastView=mlrLoadLastView(mrLastView);
  disppercent(inf);
  % if the old one exists, then set up fields
%   disppercent(-inf,'(mrOpenWindow) Restoring last view');
  if isfield(mrLastView,'view')
    % open up base anatomy from last session
    if isfield(mrLastView.view,'baseVolumes')
      disppercent(-inf,sprintf('(mrOpenWindow) installing Base Anatomies'));
      if length(mrLastView.view.baseVolumes) >= 1
        baseLoaded = 1;
        % Add it to the list of base volumes and select it
	for i = 1:length(mrLastView.view.baseVolumes)
	  % make sure sliceOrientation is not 0
	  if ~isfield(mrLastView.view.baseVolumes(i),'sliceOrientation') ...
		|| isequal(mrLastView.view.baseVolumes(i).sliceOrientation,0)
	    mrLastView.view.baseVolumes(i).sliceOrientation = 1;
	  end
	  % install the base
	  view = viewSet(view,'newBase',mrLastView.view.baseVolumes(i));
	end
      else
        %try to load 
	[view,baseLoaded] = loadAnatomy(view);
      end
      disppercent(inf);
    end
    % change group
    view = viewSet(view,'curGroup',mrLastView.view.curGroup);
    nScans = viewGet(view,'nScans');
    mlrGuiSet(view,'nScans',nScans);
    if baseLoaded
      % slice orientation from last run
      view = viewSet(view,'curBase',mrLastView.view.curBase);
      view = viewSet(view,'sliceOrientation',mrLastView.view.sliceOrientation);
      % change scan
      view = viewSet(view,'curScan',mrLastView.view.curScan);
      % change slice/corticalDepth
      if viewGet(view,'baseType') && isfield(mrLastView.view.curslice,'corticalDepth')
        view = viewSet(view,'corticalDepth',mrLastView.view.curslice.corticalDepth);
      end
      if isfield(mrLastView.view.curslice,'sliceNum')
        view = viewSet(view,'curSlice',mrLastView.view.curslice.sliceNum);
      end
    end
    % read analyses
    if isfield(mrLastView.view,'analyses')
      for anum = 1:length(mrLastView.view.analyses)
        view = viewSet(view,'newAnalysis',mrLastView.view.analyses{anum});
%         disppercent(anum /length(mrLastView.view.analyses));
      end
      view = viewSet(view,'curAnalysis',mrLastView.view.curAnalysis);
    end
    % read loaded analyses
    if isfield(mrLastView.view,'loadedAnalyses')
      for g = 1:length(mrLastView.view.loadedAnalyses)
	view = viewSet(view,'loadedAnalyses', mrLastView.view.loadedAnalyses{g},g);
      end
    end
    % read which scan we were on in for each group
    if isfield(mrLastView.view,'groupScanNum')
      for g = 1:length(mrLastView.view.groupScanNum)
	view = viewSet(view,'groupScanNum', mrLastView.view.groupScanNum(g),g);
      end
    end
    
    % read ROIs into current view
    if isfield(mrLastView.view,'ROIs')
      disppercent(-inf,sprintf('(mrOpenWindow) installing ROIs'));
      for roinum = 1:length(mrLastView.view.ROIs)
        view = viewSet(view,'newROI',mrLastView.view.ROIs(roinum));
      end
      view = viewSet(view,'currentROI',mrLastView.view.curROI);
      if ~fieldIsNotDefined(mrLastView.view,'showROIs')
	view = viewSet(view,'showROIs',mrLastView.view.showROIs);
      end
      if ~fieldIsNotDefined(mrLastView.view,'labelROIs')
	view = viewSet(view,'labelROIs',mrLastView.view.labelROIs);
      end
      if ~fieldIsNotDefined(mrLastView.view,'roiGroup')
	view = viewSet(view,'roiGroup',mrLastView.view.roiGroup);
      end
      disppercent(inf);
    end
    % check panels that need to be hidden
    if isfield(mrLastView,'viewSettings') && isfield(mrLastView.viewSettings,'panels')
      for iPanel = 1:length(mrLastView.viewSettings.panels)
	% if it is not displaying then turn it off
	if ~mrLastView.viewSettings.panels{iPanel}{4}
	  panelName = mrLastView.viewSettings.panels{iPanel}{1};
	  mlrGuiSet(view,'hidePanel',panelName);
	  % turn off check
	  mlrAdjustGUI(view,'set',panelName,'Checked','off');
	end
      end
    end
    % add here, to load more info...
    % and refresh
    disppercent(-inf,sprintf('(mrOpenWindow) Refreshing MLR display'));
    refreshMLRDisplay(view.viewNum);
    disppercent(inf);
  end

else
  [view,baseLoaded] = loadAnatomy(view);

  if baseLoaded
    refreshMLRDisplay(view.viewNum);
  end
end

% reset some preferences
mrSetPref('importROIPath','');

%%%%%%%%%%%%%%%%%%%%%
%    loadAnatomy    %
%%%%%%%%%%%%%%%%%%%%%
function [view,baseLoaded] = loadAnatomy(view)

% for when there is no mrLastView
% open an anatomy, if there is one
anatdir = dir('Anatomy/*.img');
if ~isempty(anatdir)
  baseLoaded = 1;
  % load the first anatomy in the list
  view = loadAnat(view,anatdir(1).name);
  % if it is a regular anatomy
  if viewGet(view,'baseType') == 0
    view = viewSet(view,'sliceOrientation','coronal');
    % set to display a middle slice
    baseDims = viewGet(view,'baseDims');
    baseSliceIndex = viewGet(view,'baseSliceIndex');
    view = viewSet(view,'curSlice',floor(baseDims(baseSliceIndex)/2));
  end
  % change group to last in list
  view = viewSet(view,'curGroup',viewGet(view,'numberOfGroups'));
  % and refresh
else
  baseLoaded = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%    multiAxisCallback    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%
function multiAxisCallback(hObject,eventdata)

% get gui data and v
gui = guidata(get(hObject,'Parent'));
v = viewGet(gui.viewNum,'view');

% this function gets called when single/Multi/3D radio button
% get called. 

% First, determine who was hit
controlNames = {'Single','Multi','3D'};
multiAxisVal = find(strcmp(controlNames,get(hObject,'String')));

% now set the curent base val
viewSet(v,'baseMultiAxis',multiAxisVal-1);

% redraw
refreshMLRDisplay(v.viewNum);



  
