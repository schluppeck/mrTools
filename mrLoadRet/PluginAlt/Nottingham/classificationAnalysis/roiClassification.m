% roiClassification.m
%
%        $Id: roiClassification.m 1839 2010-11-14 17:45:36Z julien $
%      usage: view = roiClassification(view,params)
%         by: alex beckett
%       date: 10/20/06
%    purpose: roi based classification data analysis
%
%             if you just want a default parameter structure you
%             can do:
% 
%             v = newView;
%             [v params] = roiClassification(v,[],'justGetParams=1','defaultParams=1','scanList=1')
%
%             Note that justGetParams,defualtParams and scanList are independent parameters, so
%             if you want, say to bring up the GUI to set the params, but not run the analysis, you
%             can do:
%             [v params] = roiClassification(v,[],'justGetParams=1');
%
function [view, params] = roiClassification(view,params,varargin)

% check arguments
if ~any(nargin == [1 2 3 4 5])
  help searchlightClassification
  return
end

mrGlobals;

% other arguments
eval(evalargs(varargin));%,[],[],{'justGetParams','defaultParams','scanList'}));
if ieNotDefined('justGetParams'),justGetParams = 0;end
if ieNotDefined('defaultParams'),defaultParams = 0;end
if ieNotDefined('scanList'),scanList = [];end
if ieNotDefined('params'),params = [];end

roi_n =  selectInList(view,'rois')
if isempty(roi_n)
    mrWarnDlg('(roiClassification) No ROI selected!');
  return
end

% First get parameters
if isempty(params) || justGetParams
  % put up the gui
%   if defaultParams
    params = roiClassGUI('thisView',view,'params',params,'defaultParams',defaultParams,'scanList',scanList);
%   else
%     params = roiClassGUI('groupName',viewGet(view,'groupName'),'scanList',scanList);
%   end
end

% Abort if params empty
if ieNotDefined('params')
  disp('(searchlightAnalysis) Searchlight Analysis cancelled');
  return
% just return parameters
elseif justGetParams
  return
end

% set the group
view = viewSet(view,'groupName',params.groupName);
% Reconcile params with current status of group and ensure that it has
% the required fields. 
params = defaultReconcileParams([],params);
if params.selectVox
    [sortFile,sortPath]=uigetfile({'*.hdr;*.img;*.nii','Nifti File (*.hdr,*.img,*.nii)'},'Pick file for ROI voxel sorting');
    sortValues=mlrImageReadNifti([sortPath,sortFile]);
end
tic
scanParams = params.scanParams;
%-------------------Main Loop Over Scans----------
set(viewGet(view,'figNum'),'Pointer','watch');drawnow;

%initialize the data we're keeping for output overlays
precision = mrGetPref('defaultPrecision');
if params.diagLinear
    diagLab=cell(1,params.scanNum(end));
    diagAcc=cell(1,params.scanNum(end));
    diagMeanAcc=cell(1,params.scanNum(end));
    diagCount=cell(1,params.scanNum(end));
end
if params.Linear
    linearLab=cell(1,params.scanNum(end));
    linearAcc=cell(1,params.scanNum(end));
    linearMeanAcc=cell(1,params.scanNum(end));
    linearCount=cell(1,params.scanNum(end));
end
if params.SVM
    svmWeight=cell(1,params.scanNum(end));
    svmAcc=cell(1,params.scanNum(end));
    svmLab=cell(1,params.scanNum(end));
    svmMeanAcc=cell(1,params.scanNum(end));
    svmMeanWeight=cell(1,params.scanNum(end));
    maxWeight=cell(1,params.scanNum(end));
    svmCount=cell(1,params.scanNum(end));
end

%loop over scans
for scanNum = params.scanNum
    scanParams{scanNum}.hdLag=input('hdLag = ');
    scanParams{scanNum}.eventLength=scanParams{scanNum}.stimDuration/2;
    scanParams{scanNum}.averageEvent=1;
    
    scanDims = viewGet(view,'dims',scanNum);
    
    [d, d.roiVoxelIndices, d.roiCoords] = loadScanRois(view,scanNum,roi_n);
    if params.selectVox
        for r = 1:size(d.roiCoords,2)
           for v = 1:size(d.roiCoords{r},2)
               sortData{r}(v)=sortValues(d.roiCoords{r}(1,v),d.roiCoords{r}(2,v),d.roiCoords{r}(3,v));
           end
        end
    end
    
    d = getStimvol(d,scanParams{scanNum});
    if isempty(d.stimvol),mrWarnDlg('No stim volumes found');return,end
    
    % do any call for preprocessing
    if ~isempty(scanParams{scanNum}.preprocess)
        d = eventRelatedPreProcess(d,scanParams{scanNum}.preprocess);
    end
    
    

    tmp_stimvol=cell(1,size(scanParams{scanNum}.stimToEVmatrix,2));
    for i=1:size(scanParams{scanNum}.stimToEVmatrix,2)
%         tmp.stimvol{i}=[d.stimvol{[find(scanParams{scanNum}.stimToEVmatrix(:,i))]}];
          tmp_stimvol{i}=[d.stimvol{logical(scanParams{scanNum}.stimToEVmatrix(:,i))}];
    end
    d.stimvol=tmp_stimvol;clear tmp_stimvol
    d.stimNames=scanParams{scanNum}.EVnames;
      
%     acc.data{scanNum}=classify_roi(view,d,params.scanParams{scanNum},roi_n,params.select_vox,params.numShuff);
%     acc.params{scanNum} = params.scanParams{scanNum};
   
    run=nan(1,size([d.stimvol{:}],2));
    for i=1:size(d.concatInfo.runTransition,1)
      run(d.concatInfo.runTransition(i,1):d.concatInfo.runTransition(i,2))=i;
      %remove any event that's too close to the end of the run
      for j=1:length(d.stimvol)
        eventsToRemove = find(d.stimvol{j}>d.dim(4)-scanParams{scanNum}.eventLength-scanParams{scanNum}.hdLag+1);
        if ~isempty(eventsToRemove)
          fprintf('(roiClassification) Removing %d event(s) because they''re too close to the end of the run\n',length(eventsToRemove));
          d.stimvol{j}(eventsToRemove) = [];
        end
      end
    end
    
    lab = zeros(1,size([d.stimvol{:}],2));
    for i=1:length(d.stimvol)
        lab(d.stimvol{i})=i;
    end

    
    d.data=squeeze(d.data);
%     d.t_mean = mean(d.data,2);
%     d.data = 100*(d.data-repmat(d.t_mean,1,size(d.data,2)))./repmat(d.t_mean,1,size(d.data,2));

    
    %pick out the eventstrings and average if requested
    idx = find(lab>0);
    if scanParams{scanNum}.eventLength==1
        m_ = d.data(:,idx+scanParams{scanNum}.hdLag);
        run=run(idx);
        lab=lab(idx);
    elseif scanParams{scanNum}.averageEvent %average across the TRs for each event
        for i=1:size(idx,2)
            m_(:,i)=mean(d.data(:,idx(i)+scanParams{scanNum}.hdLag:idx(i)+scanParams{scanNum}.eventLength+scanParams{scanNum}.hdLag-1),2);
        end
%         d.roi{1}.tSeries=m_;clear m_
        run=run(idx);
        lab=lab(idx);
        for i=1:size(unique(run),2)
%                 m_(:,run==i)=m_(:,run==i)-repmat(mean(m_(:,run==i),2),1,size(m_(:,run==i),2));
              m_(:,run==i)=100*(m_(:,run==i)-repmat(mean(m_(:,run==i),2),1,size(m_(:,run==i),2)))./repmat(mean(m_(:,run==i),2),1,size(m_(:,run==i),2));
        end
    elseif scanParams{scanNum}.eventLength>1 %create instance from each TR in the stim duration
        for i=1:size(idx,2)
            m_(:,idx(i):idx(i)+scanParams{scanNum}.eventLength-1)=d.data(:,idx(i)+scanParams{scanNum}.hdLag:idx(i)+scanParams{scanNum}.eventLength+scanParams{scanNum}.hdLag-1);
            l_(idx(i):idx(i)+scanParams{scanNum}.eventLength-1)=repmat(lab(idx(i)),1,scanParams{scanNum}.eventLength);
            r_(idx(i):idx(i)+scanParams{scanNum}.eventLength-1)=repmat(run(idx(i)),1,scanParams{scanNum}.eventLength);
        end
        nonZeros = l_~=0;
        lab=l_(nonZeros);
        run=r_(nonZeros);
        m_ = m_(:,nonZeros);
        clear l_ r_
    end
    %loop over rois in the scan
    maxxx=nan(viewGet(view,'scanDims',scanNum));
    for r = 1:size(d.roiVoxelIndices,2)
        fprintf('(roiClassification) Classiying %s from scan %i\n',viewGet(view,'roiname',roi_n(r)),scanNum);
        %prepare and sort roi data if required
        patt=m_(d.roiVoxelIndices{r},:);
        if params.selectVox==0
            patt_sort=1:size(patt,1);
        elseif (params.selectVox <  size(patt,1))
           [~, patt_sort] =sort(sortData{r},'descend');
           patt_sort=patt_sort(1:params.selectVox);
        elseif (params.selectVox >= size(patt,1))
           [~, patt_sort] =sort(sortData{r},'descend');   
        end
%         patt = ((patt' - repmat(min(patt,[],2)',size(patt',1),1))*spdiags(1./(max(patt,[],2)'-min(patt,[],2)')',0,size(patt',2),size(patt',2)))';
        %initialise outputs for classification
        diagLab{scanNum}{r}=[];
        diagAcc{scanNum}{r}=[];
        
        svmLab{scanNum}{r}=[];
        svmWeight{scanNum}{r}=[];
        svmAcc{scanNum}{r}=[];
        %loop across runs and classify
        for i=1:size(d.concatInfo.runTransition,1)
            if params.diagLinear
                diagLab{scanNum}{r}(run==i)=classify(patt(patt_sort,run==i)',patt(patt_sort,run~=i)',lab(run~=i),'diagLinear');
                diagAcc{scanNum}{r}(i)=mean(lab(run==i)==diagLab{scanNum}{r}(run==i));
            end
            if params.Linear
                linearLab{scanNum}{r}(run==i)=classify(patt(patt_sort,run==i)',patt(patt_sort,run~=i)',lab(run~=i),'linear');
                linearAcc{scanNum}{r}(i)=mean(lab(run==i)==linearLab{scanNum}{r}(run==i));
            end
            if params.SVM
%                 [svmLab_old{scanNum}{r}(run==i) svmWeight{scanNum}{r}(:,:,:,i)]=classifyWithSvm(patt(patt_sort,run==i),patt(patt_sort,run~=i),lab(run~=i));
%                 svmAcc_old{scanNum}{r}(i)=mean(lab(run==i)==svmLab_old{scanNum}{r}(run==i));
                model{scanNum}{r}(i) = svmtrain(lab(run~=i)',patt(patt_sort,run~=i)','-t 0 -q');
                [svmLab{scanNum}{r}(run==i), svmLib_accuracy{i}] = svmpredict(lab(run==i)',patt(patt_sort,run==i)',model{scanNum}{r}(i));
                svmAcc{scanNum}{r}(i)=mean(lab(run==i)==svmLab{scanNum}{r}(run==i));
            end
        end
        %calculate mean accuracy for roi
        if params.Linear
            linearMeanAcc{scanNum}{r}=mean(linearAcc{scanNum}{r});
            for i=1:length(d.stimvol)
                for j=1:length(d.stimvol)
                    linearCount{scanNum}{r}(i,j)=mean(linearLab{scanNum}{r}(lab==i)==j);
                end
            end
        end
        if params.diagLinear
            diagMeanAcc{scanNum}{r}=mean(diagAcc{scanNum}{r});
            for i=1:length(d.stimvol)
                for j=1:length(d.stimvol)
                    diagCount{scanNum}{r}(i,j)=mean(diagLab{scanNum}{r}(lab==i)==j);
                end
            end
        end
        if params.SVM
            svmMeanAcc{scanNum}{r}=mean(svmAcc{scanNum}{r});
%             svmMeanWeight{scanNum}{r}=squeeze(sum(svmWeight{scanNum}{r}(:,end,:,:),4));
%             [~,maxWeight{scanNum}{r}] = max(svmMeanWeight{scanNum}{r});
            for i=1:length(d.stimvol)
                for j=1:length(d.stimvol)
                    svmCount{scanNum}{r}(i,j)=mean(svmLab{scanNum}{r}(lab==i)==j);
                end
            end
            
%             for i = 1:length(patt_sort)
%                  [~,idx] = max(max(squeeze(svmWeight{scanNum}{r}(:,end,i,:)),[],2));
%                  maxxx(d.roiCoords{r}(1,patt_sort(i)),d.roiCoords{r}(2,patt_sort(i)),d.roiCoords{r}(3,patt_sort(i)))=idx;
%             end
        end
        
        if params.sigTest
            if params.Linear
                linearP{scanNum}{r}=binomTest(sum(linearLab{scanNum}{r}==lab),length(lab),1/length(d.stimvol));
            end
            if params.diagLinear
                diagP{scanNum}{r}=binomTest(sum(diagLab{scanNum}{r}==lab),length(lab),1/length(d.stimvol));
            end
            if params.SVM
                svmP{scanNum}{r}=binomTest(sum(svmLab{scanNum}{r}==lab),length(lab),1/length(d.stimvol));
            end
        end
        if params.nonParaTest
            disppercent(-inf,sprintf('(roiClassification) Shufflling %s from scan %i',viewGet(view,'roiname',roi_n(r)),scanNum));
            for s=1:params.numShuff
                s_lab=lab(randperm(length(lab)));
                for i=1:size(d.concatInfo.runTransition,1)
                 s_acc(i)=mean(s_lab(run==i)'==classify(patt(patt_sort,run==i)',patt(patt_sort,run~=i)',s_lab(run~=i),'diagLinear'));
                % s_acc(i)=mean(s_lab(run==i)'==classify(xxx.data(r_idx{r},run==i)',xxx.data(r_idx{r},run~=i)',s_lab(run~=i),'diagLinear'));
                end
                sm_acc{scanNum}{r}(s)=mean(s_acc);
                th_95{scanNum}{r} = prctile(sm_acc{scanNum}{r},95);
                disppercent(s/params.numShuff);
            end
            disppercent(inf);
        end
    end
end
toc
% keyboard
[pathname homedir] = fileparts(viewGet(view,'homedir'));
if params.SVM
    figure('name',[homedir ': ''tuning curves'' for Support Vector Machine'])
    for s = 1:length(params.scanNum)
        for r=1:size(svmCount{params.scanNum(s)},2)
            colors = rainbow_colors(size(svmCount{params.scanNum(s)}{r},1));
            %subplot(length(params.scanNum),size(svmCount{params.scanNum(s)},2),(s-1)*size(svmCount{params.scanNum(s)},2)+r)
            axes('outerposition',getSubplotPosition(r,s,ones(size(svmCount{params.scanNum(s)},2),1),ones(length(params.scanNum),1),0,.2))
            for i=1:size(svmCount{params.scanNum(s)}{r},1)
                plot(svmCount{params.scanNum(s)}{r}(i,:),'color',colors(i,:))
                hold on
            end
            for i=1:size(svmCount{params.scanNum(s)}{r},1)
                plot(i,svmCount{params.scanNum(s)}{r}(i,i),'o','color',colors(i,:))
            end
            axis([1 size(svmCount{params.scanNum(s)}{r},1) 0 1])
            if r==1
              ylabel(sprintf('Scan %d: %s',params.scanNum(s),params.scanParams{params.scanNum(s)}.scan));
            end
            set(gca,'XTick',1:size(svmCount{params.scanNum(s)}{r},1))
            set(gca,'XTickLabel',d.stimNames)
            legend(d.stimNames)
            line([1 size(svmCount{params.scanNum(s)}{r},1)],[1/size(svmCount{params.scanNum(s)}{r},1) 1/size(svmCount{params.scanNum(s)}{r},1)],'Color','k')
            hold on
            titleString{params.scanNum(s)}{r}={viewGet(view,'roiname',roi_n(r))}; 
            titleString{params.scanNum(s)}{r}{2}=sprintf('Mean accuracy %f',svmMeanAcc{params.scanNum(s)}{r}); 
            if params.sigTest
                titleString{params.scanNum(s)}{r}{end+1}=sprintf('Binomial p = %.6f',svmP{params.scanNum(s)}{r});
            end
            if params.nonParaTest
                titleString{params.scanNum(s)}{r}{end+1}=sprintf('(Non Para 95%% = %.6f)',th_95{params.scanNum(s)}{r});
                line([1 size(svmCount{params.scanNum(s)}{r},1)],[th_95{params.scanNum(s)}{r} th_95{params.scanNum(s)}{r}],'Color','k','linestyle','--');
                hold on
            end
             title(titleString{params.scanNum(s)}{r},'interpreter','none')  
               for i=1:8
                kk{params.scanNum(s)}{r}(:,i)=diag([svmCount{params.scanNum(s)}{r}(:,i:end),svmCount{params.scanNum(s)}{r}]);
               end
        end
    end
end

if params.diagLinear
    figure('name',[homedir ': ''tuning curves'' for Diag Linear'])
    for s = 1:length(params.scanNum)
        for r=1:size(diagCount{params.scanNum(s)},2)
            colors = rainbow_colors(size(diagCount{params.scanNum(s)}{r},1));
            %subplot(length(params.scanNum),size(diagCount{params.scanNum(s)},2),(s-1)*size(diagCount{params.scanNum(s)},2)+r)
            axes('outerposition',getSubplotPosition(r,s,ones(size(diagCount{params.scanNum(s)},2),1),ones(length(params.scanNum),1),0,.2))
            for i=1:size(diagCount{params.scanNum(s)}{r},1)
                plot(diagCount{params.scanNum(s)}{r}(i,:),'color',colors(i,:))
                hold on
            end
            for i=1:size(diagCount{params.scanNum(s)}{r},1)
                plot(i,diagCount{params.scanNum(s)}{r}(i,i),'o','color',colors(i,:))
            end
            axis([1 size(diagCount{params.scanNum(s)}{r},1) 0 1])
            if r==1
              ylabel(sprintf('Scan %d: %s',params.scanNum(s),params.scanParams{s}.scan));
            end
            set(gca,'XTick',1:size(diagCount{params.scanNum(s)}{r},1))
            set(gca,'XTickLabel',d.stimNames)
            legend(d.stimNames)
            line([1 size(diagCount{params.scanNum(s)}{r},1)],[1/size(diagCount{params.scanNum(s)}{r},1) 1/size(diagCount{params.scanNum(s)}{r},1)],'Color','k')
            hold on
            titleString{params.scanNum(s)}{r}={viewGet(view,'roiname',roi_n(r))}; 
            titleString{params.scanNum(s)}{r}{2}=sprintf('Mean accuracy %f',diagMeanAcc{params.scanNum(s)}{r}); 
            if params.sigTest
                titleString{params.scanNum(s)}{r}{end+1}=sprintf('Binomial p = %.6f',diagP{params.scanNum(s)}{r});
            end
            if params.nonParaTest
                titleString{params.scanNum(s)}{r}{end+1}=[titleString{params.scanNum(s)}{r}, sprintf('(Non Para 95%% = %.6f)',th_95{params.scanNum(s)}{r})];
                line([1 size(diagCount{params.scanNum(s)}{r},1)],[th_95{params.scanNum(s)}{r} th_95{params.scanNum(s)}{r}],'Color','k','linestyle','--');
                hold on
            end
              title(titleString{params.scanNum(s)}{r},'interpreter','none')  
        end
    end
end

keyboard

