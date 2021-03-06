%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ExpScan                                                               %
%                                                                       %
% v1:                                                                   %
% Create Exp Matrix to be loaded on DOT based on PTB scan data
% See AntonioNotes under Data\ScanHead 
% Based on previous lost ScanHead
%                                                                       %
% A. Pifferi 22/06/2017                                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% CLEARING
if ~exist('IS_DYN','var')
    clear all;
end
close all;

%% INI FILE
ExpScan_ini;

%% LOAD FILE IN
Lib=load([PathServer,PathDataIn,FileNameIn]);
DataIn=Lib.DTOFarray_block;
[ndet,nl,nt,ny,nx,nT]=size(DataIn);

%% TIME SCALE
EXP.time.axis=(1:nt)*Factor;
EXP.spc.gain=Gain;
EXP.spc.factor=Factor;
EXP.spc.n_chan=nt;
t=EXP.time.axis;

%% MISCELLANNEOUS
EXP.views=1;

%% BACKGROUND SUBTRACTION

for idet=1:ndet
    if IS_BKG, DataIn(idet,:,:,:,:,:)=DataIn(idet,:,:,:,:,:)-mean(DataIn(idet,:,BkgChan{idet},:,:,:),3); end
end

%% Squeeze Data
%[ndet,nl,nt,ny,nx,nT]
Act=squeeze(mean(DataIn(:,iL,:,:,:,rangeAct),6));
Rest=squeeze(mean(DataIn(:,iL,:,:,:,rangeRest),6));
[ndet1,nt1,ny1,nx1]=size(Rest);
if (ndet1~=ndet1)||(nt1~=nt)||(ny1~=ny)||(nx1~=nx), disp('ERROR'); end

tAct=squeeze(mean(mean(Act,3),4)); %sum over x,y
tRest=squeeze(mean(mean(Rest,3),4)); %sum over x,y
figure,
semilogy(t,tAct); hold on
semilogy(t,tRest);
for idet=1:ndet
    rect_x=Factor*RoiChan{idet}(1);
    rect_w=Factor*RoiChan{idet}(end)-rect_x;
    rect_h=max(max(tRest));
    rectangle('Position',[rect_x,1,rect_w,rect_h]);
end
title('Act & Rest integrated over x and y for 2 det');
 

%% Generate IRF

%load peak2
Data_peak_2_1 = f_read_sdt_01([PathServer,PathDataIn,FileNamePeak2]);
tplot=Factor*(1:length(Data_peak_2_1));
figure, semilogy(tplot, Data_peak_2_1, 'k'), title('Gated Spad with zero delay');
[PeakValue,ChanPeak2_1024]=max(Data_peak_2_1);

% gen IRF1
EXP.irf.t0=0;
EXP.irf.data=tRest(1,:);
[ValuePeak,EXP.irf.peak.pos]=max(EXP.irf.data);

%% Align Data
chan_shift_det2=EXP.irf.peak.pos-(ChanPeak2_1024-DTOF_reduced(1));

% plot data just for control, no further operation here
figure;
semilogy(tplot, Data_peak_2_1, 'r'); hold on;
semilogy(t,tAct(2,:),'r:');
semilogy(t,EXP.irf.data,'k');
semilogy(t,tAct(1,:),'k:');
ActShifted=zeros(size(tAct(2,:)));
ActShifted(chan_shift_det2:end)=tAct(2,1:nt+1-chan_shift_det2);
semilogy(t,ActShifted,'b:');
semilogy(tplot+Factor*(chan_shift_det2-DTOF_reduced(1)),Data_peak_2_1,'b');
title('Aligned Data');

DataSpc=zeros(nt,ny,nx);
DataRef=zeros(nt,ny,nx);

%[ndet1,nt1,ny1,nx1]=size(Rest);
DataSpc(RoiChan{1},:,:)=squeeze(Act(1,RoiChan{1},:,:));
DataSpc(chan_shift_det2+RoiChan{2},:,:)=squeeze(Act(1,RoiChan{2},:,:));
DataRef(RoiChan{1},:,:)=squeeze(Rest(1,RoiChan{1},:,:));
DataRef(chan_shift_det2+RoiChan{2},:,:)=squeeze(Rest(1,RoiChan{2},:,:));

% BINNING and Rehape
if BIN_X==2
    DataSpc=squeeze(sum(reshape(DataSpc,[nt,ny,BIN_X,nx/BIN_X]),3));
    DataRef=squeeze(sum(reshape(DataRef,[nt,ny,BIN_X,nx/BIN_X]),3));
end
EXP.data.spc=reshape(DataSpc,[nt,nx/BIN_X*ny]);
EXP.data.ref=reshape(DataRef,[nt,nx/BIN_X*ny]);
EXP.time.roi=[RoiChan{1}(1), RoiChan{2}(end)+chan_shift_det2];

%% SAVE
save([PathServer,PathDataOut,FileNameOut],'EXP');
