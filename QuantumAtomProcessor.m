classdef QuantumAtomProcessor < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        GridLayout                 matlab.ui.container.GridLayout
        
        % --- 左侧控制面板 (可滚动) ---
        ControlPanel               matlab.ui.container.Panel
        ControlGrid                matlab.ui.container.GridLayout
        
        % 文件夹区
        SelectFolderButton         matlab.ui.control.Button
        FolderPathLabel            matlab.ui.control.Label
        FolderPathField            matlab.ui.control.EditField
        
        % 运行控制区
        ProcessButton              matlab.ui.control.Button
        StopButton                 matlab.ui.control.Button
        AutoProcessCheckBox        matlab.ui.control.CheckBox
        RefreshIntervalField       matlab.ui.control.NumericEditField
        RefreshIntervalLabel       matlab.ui.control.Label
        
        % --- 参数设置面板 ---
        ParametersPanel            matlab.ui.container.Panel
        
        % 阈值参数
        ThresholdField            matlab.ui.control.NumericEditField
        ThresholdLabel            matlab.ui.control.Label
        AutoThresholdButton       matlab.ui.control.Button
        
        % 实验结构参数
        SitesField                matlab.ui.control.NumericEditField
        SitesLabel                matlab.ui.control.Label
        
        RepeatsField              matlab.ui.control.NumericEditField
        RepeatsLabel              matlab.ui.control.Label
        
        % ROI半径
        ROIRadiusField            matlab.ui.control.NumericEditField
        ROIRadiusLabel            matlab.ui.control.Label
        
        % 变量设置 (X轴)
        VarStartField             matlab.ui.control.NumericEditField
        VarStartLabel             matlab.ui.control.Label
        VarStepField              matlab.ui.control.NumericEditField
        VarStepLabel              matlab.ui.control.Label
        
        % ROI设置
        ROIControlsGrid           matlab.ui.container.GridLayout
        ROIModeDropDown           matlab.ui.control.DropDown
        ROIModeLabel              matlab.ui.control.Label
        SelectROIButton           matlab.ui.control.Button
        ClearROIButton            matlab.ui.control.Button
        
        % --- 图像处理面板 ---
        ImageProcessPanel         matlab.ui.container.Panel
        ColorMinField             matlab.ui.control.NumericEditField
        ColorMinLabel             matlab.ui.control.Label
        ColorMaxField             matlab.ui.control.NumericEditField
        ColorMaxLabel             matlab.ui.control.Label
        AutoScaleButton           matlab.ui.control.Button
        ApplyScaleButton          matlab.ui.control.Button
        
        % --- 数据管理面板 ---
        ExportPanel               matlab.ui.container.Panel
        ImportDataButton          matlab.ui.control.Button   % 新增：导入数据
        ExportDataButton          matlab.ui.control.Button
        ExportFiguresButton       matlab.ui.control.Button
        ImportROIButton           matlab.ui.control.Button
        ExportROIButton           matlab.ui.control.Button
        
        % --- 显示区域 (Tabs) ---
        DisplayTabGroup           matlab.ui.container.TabGroup
        
        PreviewTab                matlab.ui.container.Tab
        LatestOddAxes             matlab.ui.control.UIAxes
        LatestEvenAxes            matlab.ui.control.UIAxes
        
        LoadingTab                matlab.ui.container.Tab
        LoadingHistoryAxes        matlab.ui.control.UIAxes 
        SiteLoadingAxes           matlab.ui.control.UIAxes 
        LoadingHeatmapAxes        matlab.ui.control.UIAxes 
        
        SurvivalTab               matlab.ui.container.Tab
        SurvivalGrid              matlab.ui.container.GridLayout
        SurvivalControlGrid       matlab.ui.container.GridLayout
        SurvivalAxes              matlab.ui.control.UIAxes
        SiteSurvivalAxes          matlab.ui.control.UIAxes
        FitGaussianButton         matlab.ui.control.Button
        FitStatusLabel            matlab.ui.control.Label
        SurvivalSiteSelectorLabel matlab.ui.control.Label
        SurvivalSiteSelectorField matlab.ui.control.NumericEditField
        ShowAllSiteSurvivalButton matlab.ui.control.Button
        
        BimodalTab                matlab.ui.container.Tab
        BimodalGrid               matlab.ui.container.GridLayout
        BimodalControlsGrid       matlab.ui.container.GridLayout
        TotalDistAxes             matlab.ui.control.UIAxes  
        SingleDistAxes            matlab.ui.control.UIAxes  
        SiteSelectorField         matlab.ui.control.NumericEditField 
        SiteSelectorLabel         matlab.ui.control.Label
        ShowAllSitesButton        matlab.ui.control.Button
        
        AvgImageTab               matlab.ui.container.Tab
        AvgImageAxes              matlab.ui.control.UIAxes
        UpdateAvgImageButton      matlab.ui.control.Button
        
        % --- H5 信息显示 Tab ---
        InfoTab                   matlab.ui.container.Tab
        InfoGrid                  matlab.ui.container.GridLayout
        LoadH5Button              matlab.ui.control.Button
        H5PathLabel               matlab.ui.control.Label
        InfoTextArea              matlab.ui.control.TextArea
        
        % --- 状态栏 ---
        StatusPanel               matlab.ui.container.Panel
        StatusLabel               matlab.ui.control.Label
        ProgressBar               matlab.ui.control.Label
        LoadingRateLabel          matlab.ui.control.Label
        SurvivalRateLabel         matlab.ui.control.Label
    end

    % Properties for data storage
    properties (Access = private)
        rootFolder
        tifFiles
        
        % 核心数据
        imgavg               
        imgavg_odd           
        latestOddImg         
        latestEvenImg        
        processedFileCount   
        
        mask                 
        masklist             
        roiCoordinates       
        roiHandles           
        
        % 动态计算 Sites
        sites                
        
        threshold            
        photonn              
        
        % 结果数据
        loadingRate_odd      
        loadingRate_site     
        survivalRate         
        survivalError        
        survivalX            
        siteSurvivalRates    
        siteSurvivalErrors   
        fitResult            
        
        % 控制标志
        isProcessing
        autoProcessTimer
        settingsFile = 'QuantumProcessor_Settings.mat';
        
        % 显示设置
        colorMin
        colorMax
    end

    % Callbacks
    methods (Access = private)
        
        % --- 文件夹与运行 ---
        function SelectFolderButtonPushed(app, event)
            startPath = app.FolderPathField.Value;
            if isempty(startPath) || ~isfolder(startPath)
                startPath = pwd;
            end
            
            folder = uigetdir(startPath, '选择数据文件夹');
            if folder ~= 0
                app.rootFolder = folder;
                app.FolderPathField.Value = folder;
                app.StatusLabel.Text = '状态: 文件夹已选择';
                
                % 重置数据
                app.resetData();
                
                % 检查 roi0.mat 是否存在
                roi0Path = fullfile(folder, 'roi0.mat');
                if isfile(roi0Path)
                    try
                        roiData = load(roi0Path);
                        if isfield(roiData, 'roiCoordinates')
                            app.roiCoordinates = roiData.roiCoordinates;
                            app.sites = size(app.roiCoordinates, 1);
                            app.SitesField.Value = app.sites;
                            
                            app.ROIModeDropDown.Value = '手动';
                            app.StatusLabel.Text = '状态: 检测到 roi0.mat，已加载预设ROI';
                        end
                    catch
                        uialert(app.UIFigure, 'roi0.mat 加载失败', '警告');
                    end
                end
                
                app.scanTifFiles();
                app.StatusLabel.Text = [app.StatusLabel.Text sprintf(' | 发现 %d 个文件', length(app.tifFiles))];
            end
        end
        
        function ProcessButtonPushed(app, event)
            if isempty(app.rootFolder)
                uialert(app.UIFigure, '请先选择文件夹', '错误');
                return;
            end
            
            app.sites = app.SitesField.Value;
            
            app.isProcessing = true;
            app.ProcessButton.Enable = 'off';
            app.StopButton.Enable = 'on';
            app.FitGaussianButton.Enable = 'off';
            
            if ~contains(app.StatusLabel.Text, 'roi0')
                app.StatusLabel.Text = '状态: 正在处理...';
            end
            
            try
                app.processDataIncremental();
            catch ME
                app.StatusLabel.Text = ['错误: ' ME.message];
                app.isProcessing = false;
                app.ProcessButton.Enable = 'on';
                app.StopButton.Enable = 'off';
            end
        end
        
        function StopButtonPushed(app, event)
            app.isProcessing = false;
            app.ProcessButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.FitGaussianButton.Enable = 'on';
            app.StatusLabel.Text = '状态: 已停止';
            
            if ~isempty(app.autoProcessTimer) && isvalid(app.autoProcessTimer)
                stop(app.autoProcessTimer);
            end
            app.AutoProcessCheckBox.Value = 0;
        end
        
        function AutoProcessCheckBoxValueChanged(app, event)
            if app.AutoProcessCheckBox.Value
                if isempty(app.rootFolder)
                    app.AutoProcessCheckBox.Value = 0;
                    uialert(app.UIFigure, '请先选择文件夹', '提示');
                    return;
                end
                
                app.sites = app.SitesField.Value;
                
                period = app.RefreshIntervalField.Value;
                if period < 0.5, period = 0.5; end
                
                app.autoProcessTimer = timer('Period', period, ...
                    'ExecutionMode', 'fixedRate', ...
                    'TimerFcn', @(~,~) app.autoProcess());
                start(app.autoProcessTimer);
                
                app.StatusLabel.Text = '状态: 自动监控模式运行中...';
                app.ProcessButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                app.FitGaussianButton.Enable = 'off';
            else
                if ~isempty(app.autoProcessTimer) && isvalid(app.autoProcessTimer)
                    stop(app.autoProcessTimer);
                    delete(app.autoProcessTimer);
                end
                app.StatusLabel.Text = '状态: 自动监控已停止';
                app.ProcessButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.FitGaussianButton.Enable = 'on';
            end
        end
        
        % --- H5 文件读取回调 ---
        function LoadH5ButtonPushed(app, event)
            startPath = app.rootFolder;
            if isempty(startPath), startPath = pwd; end
            
            [file, path] = uigetfile('*.h5', '选择 ARTIQ 实验数据 (.h5)', startPath);
            
            if file ~= 0
                fullPath = fullfile(path, file);
                app.H5PathLabel.Text = file;
                
                try
                    % 1. 读取 n_cycles
                    try
                        n_cycles = h5read(fullPath, "/datasets/n_cycles");
                        str_cycles = sprintf('n_cycles: %d', n_cycles);
                    catch
                        str_cycles = 'n_cycles: Not Found';
                    end
                    
                    % 2. 读取 fre_scan
                    try
                        fre_scan = h5read(fullPath, "/datasets/fre_scan");
                        if numel(fre_scan) > 10
                            valStr = sprintf('%.4f ... (size: %d)', fre_scan(1), numel(fre_scan));
                        else
                            valStr = mat2str(fre_scan, 4);
                        end
                        str_fre = sprintf('fre_scan: %s', valStr);
                        full_fre = sprintf('fre_scan (Hz):\n%s', mat2str(fre_scan, 6));
                    catch
                        str_fre = 'fre_scan: Not Found';
                        full_fre = '';
                    end
                    
                    % 3. 读取 time_scan
                    try
                        time_scan = h5read(fullPath, "/datasets/time_scan");
                        if numel(time_scan) > 10
                            valStr = sprintf('%.4f ... (size: %d)', time_scan(1), numel(time_scan));
                        else
                            valStr = mat2str(time_scan, 4);
                        end
                        str_time = sprintf('time_scan: %s', valStr);
                        full_time = sprintf('time_scan (s):\n%s', mat2str(time_scan, 6));
                    catch
                        str_time = 'time_scan: Not Found';
                        full_time = '';
                    end
                    
                    % 4. 读取 Completion_time 
                    try
                        ct = h5read(fullPath, "/datasets/Completion_time");
                        str_comp = sprintf('Completion_time: %s', mat2str(ct, 6));
                    catch
                        str_comp = 'Completion_time: Not Found';
                    end
                    
                    % 组合输出文本
                    displayStr = {
                        sprintf('File Path: %s', fullPath);
                        '----------------------------------------';
                        str_cycles;
                        str_comp;
                        '----------------------------------------';
                        str_fre;
                        str_time;
                        '----------------------------------------';
                        '详细数据:';
                        full_fre;
                        full_time
                    };
                    
                    app.InfoTextArea.Value = displayStr;
                    
                catch ME
                    app.InfoTextArea.Value = {'读取文件出错:', ME.message};
                    uialert(app.UIFigure, ['H5读取失败: ' ME.message], '错误');
                end
            end
        end

        % --- 拟合功能 ---
        function FitGaussianButtonPushed(app, event)
            if isempty(app.survivalRate) || isempty(app.survivalX)
                uialert(app.UIFigure, '没有足够的数据进行拟合', '提示');
                return;
            end
            
            x = app.survivalX(:);
            y = app.survivalRate(:);
            
            app.StatusLabel.Text = '状态: 正在拟合高斯函数...';
            
            try
                ft = fittype('gauss1');
                [maxY, idx] = max(y);
                peakX = x(idx);
                widthGuess = (max(x) - min(x)) / 5;
                if widthGuess == 0, widthGuess = 1; end
                
                opts = fitoptions(ft);
                opts.StartPoint = [maxY, peakX, widthGuess];
                
                [fitObj, gof] = fit(x, y, ft, opts);
                app.fitResult = fitObj;
                
                x_smooth = linspace(min(x), max(x), 200);
                y_smooth = feval(fitObj, x_smooth);
                
                hold(app.SurvivalAxes, 'on');
                hOld = findobj(app.SurvivalAxes, 'Tag', 'FitLine');
                delete(hOld);
                
                plot(app.SurvivalAxes, x_smooth, y_smooth, 'r-', 'LineWidth', 2, 'Tag', 'FitLine');
                hold(app.SurvivalAxes, 'off');
                
                title(app.SurvivalAxes, sprintf('Overall Survival - Fit: R^2=%.3f, Peak=%.2f, Center=%.3f', ...
                    gof.rsquare, fitObj.a1, fitObj.b1));
                
                app.FitStatusLabel.Text = sprintf('R^2: %.4f | Ctr: %.4f', gof.rsquare, fitObj.b1);
                app.StatusLabel.Text = '状态: 拟合完成';
                
            catch ME
                uialert(app.UIFigure, ['拟合失败: ' ME.message], '错误');
            end
        end

        % --- 阈值和图像设置 ---
        function AutoThresholdButtonPushed(app, event)
            if isempty(app.photonn)
                uialert(app.UIFigure, '没有数据可计算阈值', '错误');
                return;
            end
            app.calculateAutoThreshold();
            if ~isempty(app.masklist)
                app.updateResults();
            end
        end
        
        function AutoScaleButtonPushed(app, event)
            targetImg = app.latestOddImg;
            if isempty(targetImg), targetImg = app.imgavg; end
            if isempty(targetImg)
                uialert(app.UIFigure, '请先加载图像', '错误');
                return;
            end
            
            sortedVals = sort(targetImg(:));
            nPixels = numel(sortedVals);
            app.colorMin = sortedVals(floor(nPixels * 0.01) + 1);
            app.colorMax = sortedVals(floor(nPixels * 0.995) + 1);
            app.ColorMinField.Value = app.colorMin;
            app.ColorMaxField.Value = app.colorMax;
            app.updateImageDisplays();
        end
        
        function ApplyScaleButtonPushed(app, event)
            app.colorMin = app.ColorMinField.Value;
            app.colorMax = app.ColorMaxField.Value;
            app.updateImageDisplays();
        end
        
        function UpdateAvgImageButtonPushed(app, event)
            app.updateImageDisplays();
        end
        
        % --- ROI 相关回调 ---
        function SelectROIButtonPushed(app, event)
            if strcmp(app.ROIModeDropDown.Value, '手动')
                if isempty(app.imgavg_odd)
                    uialert(app.UIFigure, '无图像数据，请先运行处理', '错误');
                    return;
                end
                app.manualSelectROI();
            else
                uialert(app.UIFigure, '请先切换ROI模式为"手动"', '提示');
            end
        end
        
        function ClearROIButtonPushed(app, event)
            app.clearROIs();
        end
        
        function clearROIs(app)
            app.roiCoordinates = [];
            app.mask = [];
            app.masklist = [];
            if ~isempty(app.roiHandles)
                delete(app.roiHandles);
                app.roiHandles = [];
            end
            app.StatusLabel.Text = '状态: ROI已清除';
        end
        
        function ImportROIButtonPushed(app, event)
            [file, path] = uigetfile('*.mat', '选择ROI文件');
            if file ~= 0
                data = load(fullfile(path, file));
                if isfield(data, 'roiCoordinates')
                    app.roiCoordinates = data.roiCoordinates;
                    app.sites = size(app.roiCoordinates, 1);
                    app.SitesField.Value = app.sites; 
                    
                    app.createMaskFromCoordinates();
                    app.StatusLabel.Text = '状态: ROI已导入';
                    app.displayROIsOnImage();
                    if ~isempty(app.photonn)
                        uialert(app.UIFigure, 'ROI已变更，请重新点击"开始处理"刷新数据', '提示');
                        app.resetData();
                    end
                end
            end
        end
        
        function ExportROIButtonPushed(app, event)
            if isempty(app.roiCoordinates)
                uialert(app.UIFigure, '没有ROI数据可导出', '错误');
                return;
            end
            [file, path] = uiputfile('*.mat', '保存ROI');
            
            if file ~= 0
                roiCoordinates = app.roiCoordinates;
                mask = app.mask;
                masklist = app.masklist;
                sites = app.sites;
                save(fullfile(path, file), 'roiCoordinates', 'mask', 'masklist', 'sites');
                app.StatusLabel.Text = '状态: ROI已导出';
            end
        end
        
        % --- 导入数据 ---
        function ImportDataButtonPushed(app, event)
            % 选择文件
            defaultPath = app.rootFolder;
            if isempty(defaultPath) || ~isfolder(defaultPath)
                defaultPath = pwd;
            end
            
            [file, path] = uigetfile('*.mat', '选择已导出的数据文件', defaultPath);
            if file == 0
                return;
            end
            
            app.StatusLabel.Text = '状态: 正在导入数据...';
            drawnow;
            
            try
                loadedData = load(fullfile(path, file));
                
                % 检查数据结构
                if isfield(loadedData, 'data')
                    data = loadedData.data;
                else
                    data = loadedData;
                end
                
                % 验证必要字段
                if ~isfield(data, 'photonn')
                    uialert(app.UIFigure, '数据文件格式不正确，缺少 photonn 字段', '错误');
                    return;
                end
                
                % 重置当前数据
                app.resetData();
                
                % === 恢复核心数据 ===
                app.photonn = data.photonn;
                app.sites = size(app.photonn, 1);
                app.SitesField.Value = app.sites;
                app.processedFileCount = size(app.photonn, 2);
                
                % 恢复装载率数据
                if isfield(data, 'loadingRate_odd')
                    app.loadingRate_odd = data.loadingRate_odd;
                end
                if isfield(data, 'loadingRate_site')
                    app.loadingRate_site = data.loadingRate_site;
                end
                
                % 恢复存活率数据
                if isfield(data, 'survivalRate')
                    app.survivalRate = data.survivalRate;
                end
                if isfield(data, 'survivalError')
                    app.survivalError = data.survivalError;
                end
                if isfield(data, 'siteSurvivalRates')
                    app.siteSurvivalRates = data.siteSurvivalRates;
                end
                if isfield(data, 'siteSurvivalErrors')
                    app.siteSurvivalErrors = data.siteSurvivalErrors;
                end
                if isfield(data, 'x_values')
                    app.survivalX = data.x_values;
                end
                
                % 恢复拟合结果
                if isfield(data, 'fit_result')
                    app.fitResult = data.fit_result;
                end
                
                % 恢复ROI坐标
                if isfield(data, 'roiCoordinates')
                    app.roiCoordinates = data.roiCoordinates;
                end
                
                % 恢复平均图像
                if isfield(data, 'imgavg')
                    app.imgavg = data.imgavg;
                    app.imgavg_odd = data.imgavg;
                end
                
                % 恢复参数设置
                if isfield(data, 'parameters')
                    params = data.parameters;
                    if isfield(params, 'threshold')
                        app.threshold = params.threshold;
                        app.ThresholdField.Value = params.threshold;
                    end
                    if isfield(params, 'varStart')
                        app.VarStartField.Value = params.varStart;
                    end
                    if isfield(params, 'varStep')
                        app.VarStepField.Value = params.varStep;
                    end
                    if isfield(params, 'roiRadius')
                        app.ROIRadiusField.Value = params.roiRadius;
                    end
                    if isfield(params, 'repeats')
                        app.RepeatsField.Value = params.repeats;
                    end
                    if isfield(params, 'sites')
                        app.sites = params.sites;
                        app.SitesField.Value = params.sites;
                    end
                end
                
                % 恢复源文件夹路径
                if isfield(data, 'sourceFolder') && ~isempty(data.sourceFolder)
                    app.rootFolder = data.sourceFolder;
                    app.FolderPathField.Value = data.sourceFolder;
                end
                
                % 重建mask (如果有ROI坐标和图像)
                if ~isempty(app.roiCoordinates) && ~isempty(app.imgavg)
                    app.createMaskFromCoordinates();
                end
                
                % 重新绘制所有图表
                app.displayImportedData();
                
                % 显示导入信息
                infoStr = sprintf('状态: 数据已导入 (%s)', file);
                if isfield(data, 'timestamp')
                    infoStr = [infoStr sprintf(' | 原保存时间: %s', datestr(data.timestamp))];
                end
                app.StatusLabel.Text = infoStr;
                app.ProgressBar.Text = sprintf('进度: %d 帧', app.processedFileCount);
                
            catch ME
                uialert(app.UIFigure, ['导入失败: ' ME.message], '错误');
                app.StatusLabel.Text = '状态: 导入失败';
            end
        end
        
        % --- 显示导入的数据 ---
        function displayImportedData(app)
            % === 1. 绘制装载率历史 ===
            if ~isempty(app.loadingRate_odd)
                cla(app.LoadingHistoryAxes);
                plot(app.LoadingHistoryAxes, 1:length(app.loadingRate_odd), app.loadingRate_odd*100, 'o-', 'LineWidth', 1.2);
                ylim(app.LoadingHistoryAxes, [0 100]);
                grid(app.LoadingHistoryAxes, 'on');
                xlabel(app.LoadingHistoryAxes, '图像序列');
                ylabel(app.LoadingHistoryAxes, '装载率(%)');
                title(app.LoadingHistoryAxes, '所有奇数图像装载率');
                app.LoadingRateLabel.Text = sprintf('装载率: %.1f%%', mean(app.loadingRate_odd)*100);
            end
            
            % === 2. 绘制各点装载率柱状图和热图 ===
            if ~isempty(app.loadingRate_site)
                cla(app.SiteLoadingAxes);
                bar(app.SiteLoadingAxes, 1:app.sites, app.loadingRate_site*100);
                ylim(app.SiteLoadingAxes, [0 100]);
                xlabel(app.SiteLoadingAxes, 'Site Index');
                ylabel(app.SiteLoadingAxes, '装载率(%)');
                title(app.SiteLoadingAxes, '所有点装载率');
                grid(app.SiteLoadingAxes, 'on');
                
                % 热图
                cla(app.LoadingHeatmapAxes);
                rates = app.loadingRate_site * 100;
                [nRows, nCols] = app.getArrayDimensions();
                
                if length(rates) < nRows*nCols
                    rates = [rates; nan(nRows*nCols - length(rates), 1)];
                end
                
                heatmapMat = reshape(rates(1:nRows*nCols), nCols, nRows)';
                
                imagesc(app.LoadingHeatmapAxes, heatmapMat);
                colormap(app.LoadingHeatmapAxes, 'hot');
                colorbar(app.LoadingHeatmapAxes);
                
                minRate = min(rates, [], 'omitnan');
                maxRate = max(rates, [], 'omitnan');
                if isempty(minRate), minRate = 0; end
                if isempty(maxRate), maxRate = 100; end
                if minRate == maxRate, maxRate = minRate + 1e-3; end
                caxis(app.LoadingHeatmapAxes, [minRate maxRate]);
                
                title(app.LoadingHeatmapAxes, sprintf('装载率热图 [Shape: %dx%d]', nRows, nCols));
                axis(app.LoadingHeatmapAxes, 'equal', 'tight');
                app.LoadingHeatmapAxes.XTick = 1:nCols;
                app.LoadingHeatmapAxes.YTick = 1:nRows;
            end
            
            % === 3. 绘制总体存活率 ===
            if ~isempty(app.survivalRate) && ~isempty(app.survivalX)
                cla(app.SurvivalAxes);
                if ~isempty(app.survivalError)
                    errorbar(app.SurvivalAxes, app.survivalX, app.survivalRate, app.survivalError, 'bo-', 'LineWidth', 1.5);
                else
                    plot(app.SurvivalAxes, app.survivalX, app.survivalRate, 'bo-', 'LineWidth', 1.5);
                end
                ylim(app.SurvivalAxes, [-0.1 1.1]);
                xlabel(app.SurvivalAxes, 'Variable');
                ylabel(app.SurvivalAxes, 'Survival Rate');
                grid(app.SurvivalAxes, 'on');
                title(app.SurvivalAxes, sprintf('Overall Survival (Groups: %d)', length(app.survivalRate)));
                
                if ~isempty(app.survivalRate)
                    app.SurvivalRateLabel.Text = sprintf('存活率: %.2f', app.survivalRate(end));
                end
                
                % 如果有拟合结果，也绘制拟合曲线
                if ~isempty(app.fitResult)
                    hold(app.SurvivalAxes, 'on');
                    x_smooth = linspace(min(app.survivalX), max(app.survivalX), 200);
                    y_smooth = feval(app.fitResult, x_smooth);
                    plot(app.SurvivalAxes, x_smooth, y_smooth, 'r-', 'LineWidth', 2, 'Tag', 'FitLine');
                    hold(app.SurvivalAxes, 'off');
                    
                    % 更新拟合状态
                    try
                        app.FitStatusLabel.Text = sprintf('Loaded Fit | Ctr: %.4f', app.fitResult.b1);
                    catch
                        app.FitStatusLabel.Text = 'Loaded Fit';
                    end
                end
            end
            
            % === 4. 绘制单点阵存活率 ===
            app.updateSingleSiteSurvival();
            
            % === 5. 绘制双峰分布 ===
            if ~isempty(app.photonn)
                % 绘制总分布并计算阈值
                app.calculateAutoThreshold();
                
                % 绘制单点分布
                app.updateSingleSiteDistribution();
            end
            
            % === 6. 更新图像显示 ===
            if ~isempty(app.imgavg)
                % 自动设置颜色范围
                sortedVals = sort(app.imgavg(:));
                nPixels = numel(sortedVals);
                app.colorMin = sortedVals(max(1, floor(nPixels * 0.01)));
                app.colorMax = sortedVals(min(nPixels, floor(nPixels * 0.995)));
                app.ColorMinField.Value = app.colorMin;
                app.ColorMaxField.Value = app.colorMax;
                
                % 显示图像
                imagesc(app.AvgImageAxes, app.imgavg, [app.colorMin, app.colorMax]);
                title(app.AvgImageAxes, '平均图像 (导入数据)');
                colormap(app.AvgImageAxes, 'hot');
                colorbar(app.AvgImageAxes);
                axis(app.AvgImageAxes, 'image');
                
                % 显示ROI
                if ~isempty(app.roiCoordinates)
                    app.displayROIsOnImage();
                end
            end
            
            % === 7. 启用相关按钮 ===
            app.FitGaussianButton.Enable = 'on';
            app.ProcessButton.Enable = 'on';
            app.StopButton.Enable = 'off';
        end
        
        % --- 双峰分布相关回调 ---
        function SiteSelectorValueChanged(app, event)
            app.updateSingleSiteDistribution();
        end
        
        function ShowAllSitesButtonPushed(app, event)
            if isempty(app.photonn)
                uialert(app.UIFigure, '没有数据', '提示');
                return;
            end
            
            fig = uifigure('Name', '所有点阵分布', 'Position', [100 100 1000 600]);
            g = uigridlayout(fig);
            
            [nRows, nCols] = app.getArrayDimensions();
            
            g.RowHeight = repmat({'1x'}, 1, nRows);
            g.ColumnWidth = repmat({'1x'}, 1, nCols);
            
            for i = 1:app.sites
                ax = uiaxes(g);
                
                rowIdx = ceil(i / nCols);
                colIdx = mod(i-1, nCols) + 1;
                
                ax.Layout.Row = rowIdx;
                ax.Layout.Column = colIdx;
                
                data = app.photonn(i, :);
                histogram(ax, data, 40);
                title(ax, sprintf('Site %d', i));
                if rowIdx == nRows
                    xlabel(ax, 'Counts');
                end
                ax.FontSize = 8;
            end
        end
        
        % --- 存活率点阵选择回调 ---
        function SurvivalSiteSelectorValueChanged(app, event)
            app.updateSingleSiteSurvival();
        end
        
        function ShowAllSiteSurvivalButtonPushed(app, event)
            if isempty(app.siteSurvivalRates)
                uialert(app.UIFigure, '没有存活率数据', '提示');
                return;
            end
            
            fig = uifigure('Name', '所有点阵存活率', 'Position', [100 100 1200 700]);
            g = uigridlayout(fig);
            
            [nRows, nCols] = app.getArrayDimensions();
            
            g.RowHeight = repmat({'1x'}, 1, nRows);
            g.ColumnWidth = repmat({'1x'}, 1, nCols);
            
            for i = 1:app.sites
                ax = uiaxes(g);
                
                rowIdx = ceil(i / nCols);
                colIdx = mod(i-1, nCols) + 1;
                
                ax.Layout.Row = rowIdx;
                ax.Layout.Column = colIdx;
                
                validData = ~isnan(app.siteSurvivalRates(i, :));
                if any(validData)
                    if ~isempty(app.siteSurvivalErrors)
                        errorbar(ax, ...
                            app.survivalX(validData), ...
                            app.siteSurvivalRates(i, validData), ...
                            app.siteSurvivalErrors(i, validData), ...
                            'o-', 'LineWidth', 1.2);
                    else
                        plot(ax, ...
                            app.survivalX(validData), ...
                            app.siteSurvivalRates(i, validData), ...
                            'o-', 'LineWidth', 1.2);
                    end
                    ylim(ax, [-0.1 1.1]);
                    grid(ax, 'on');
                end
                
                title(ax, sprintf('Site %d', i), 'FontSize', 9);
                if rowIdx == nRows
                    xlabel(ax, 'Variable', 'FontSize', 8);
                end
                if colIdx == 1
                    ylabel(ax, 'Survival', 'FontSize', 8);
                end
                ax.FontSize = 7;
            end
        end
        
        % --- 导出数据 ---
        function ExportDataButtonPushed(app, event)
            if isempty(app.photonn)
                uialert(app.UIFigure, '没有数据可导出', '错误');
                return;
            end
            
            defaultPath = app.rootFolder;
            if isempty(defaultPath) || ~isfolder(defaultPath)
                defaultPath = pwd;
            end
            
            [file, path] = uiputfile('*.mat', '保存实验数据', defaultPath);
            if file ~= 0
                data = struct();
                
                % 核心数据
                data.photonn = app.photonn;
                data.loadingRate_odd = app.loadingRate_odd;
                data.loadingRate_site = app.loadingRate_site;
                
                % 存活率数据
                data.survivalRate = app.survivalRate;
                data.survivalError = app.survivalError;
                data.siteSurvivalRates = app.siteSurvivalRates;
                data.siteSurvivalErrors = app.siteSurvivalErrors;
                data.x_values = app.survivalX;
                
                % 拟合结果
                if ~isempty(app.fitResult)
                    data.fit_result = app.fitResult;
                end
                
                % 参数
                data.parameters.threshold = app.ThresholdField.Value;
                data.parameters.varStart = app.VarStartField.Value;
                data.parameters.varStep = app.VarStepField.Value;
                data.parameters.sites = app.sites;
                data.parameters.roiRadius = app.ROIRadiusField.Value;
                data.parameters.repeats = app.RepeatsField.Value;
                
                % ROI和图像
                data.roiCoordinates = app.roiCoordinates;
                data.imgavg = app.imgavg;
                
                % 元数据
                data.timestamp = datetime('now');
                data.sourceFolder = app.rootFolder;
                data.fileCount = app.processedFileCount;
                
                save(fullfile(path, file), 'data');
                app.StatusLabel.Text = '状态: 数据已导出';
            end
        end
        
        % --- 导出图像 ---
        function ExportFiguresButtonPushed(app, event)
            defaultPath = app.rootFolder;
            if isempty(defaultPath) || ~isfolder(defaultPath)
                defaultPath = pwd;
            end
            
            folder = uigetdir(defaultPath, '选择保存图像的文件夹');
            if folder ~= 0
                timestamp = datestr(now, 'yyyymmdd_HHMMSS');
                try
                    exportgraphics(app.SurvivalAxes, fullfile(folder, [timestamp '_survival_overall.png']));
                    exportgraphics(app.SiteSurvivalAxes, fullfile(folder, [timestamp '_survival_single_site.png']));
                    exportgraphics(app.LoadingHistoryAxes, fullfile(folder, [timestamp '_loading_history.png']));
                    exportgraphics(app.SiteLoadingAxes, fullfile(folder, [timestamp '_loading_bars.png']));
                    exportgraphics(app.LoadingHeatmapAxes, fullfile(folder, [timestamp '_loading_heatmap.png']));
                    exportgraphics(app.TotalDistAxes, fullfile(folder, [timestamp '_histogram_total.png']));
                    app.StatusLabel.Text = '状态: 图像已导出';
                catch ME
                    uialert(app.UIFigure, ['导出错误: ' ME.message], '错误');
                end
            end
        end
        
        % --- 核心处理逻辑 ---
        
        function resetData(app)
            app.processedFileCount = 0;
            app.photonn = [];
            app.imgavg = [];
            app.imgavg_odd = [];
            app.latestOddImg = [];
            app.latestEvenImg = [];
            
            app.mask = [];
            app.masklist = [];
            app.roiCoordinates = [];
            app.fitResult = [];
            app.siteSurvivalRates = [];
            app.siteSurvivalErrors = [];
            app.loadingRate_odd = [];
            app.loadingRate_site = [];
            app.survivalRate = [];
            app.survivalError = [];
            app.survivalX = [];
            
            cla(app.LatestOddAxes);
            cla(app.LatestEvenAxes);
            cla(app.AvgImageAxes);
            cla(app.LoadingHistoryAxes);
            cla(app.SiteLoadingAxes);
            cla(app.LoadingHeatmapAxes);
            cla(app.SurvivalAxes);
            cla(app.SiteSurvivalAxes);
            cla(app.TotalDistAxes);
            cla(app.SingleDistAxes);
            app.FitStatusLabel.Text = '';
            app.LoadingRateLabel.Text = '装载率: --';
            app.SurvivalRateLabel.Text = '存活率: --';
        end
        
        function scanTifFiles(app)
            app.tifFiles = dir(fullfile(app.rootFolder, '**/*.tif'));
            try
                fileNames = {app.tifFiles.name};
                [~, idx] = natsortfiles(fileNames);
                app.tifFiles = app.tifFiles(idx);
            catch
                [~, idx] = sort({app.tifFiles.name});
                app.tifFiles = app.tifFiles(idx);
            end
        end
        
        function autoProcess(app)
            app.scanTifFiles();
            totalFiles = length(app.tifFiles);
            if totalFiles > app.processedFileCount
                app.StatusLabel.Text = sprintf('状态: 发现 %d 个新文件，正在处理...', totalFiles - app.processedFileCount);
                app.processDataIncremental();
            end
        end
        
        function processDataIncremental(app)
            totalFiles = length(app.tifFiles);
            if totalFiles == 0, return; end
            
            startIdx = app.processedFileCount + 1;
            
            for k = startIdx:totalFiles
                if ~app.isProcessing && ~app.AutoProcessCheckBox.Value, break; end
                
                try
                    rawImg = imread(fullfile(app.tifFiles(k).folder, app.tifFiles(k).name));
                catch
                    continue; 
                end
                
                img = double(rawImg) - 800; 
                img(img < 0) = 0;
                
                if isempty(app.imgavg)
                    app.imgavg = img;
                    
                    if isempty(app.masklist) && ~isempty(app.roiCoordinates)
                        app.createMaskFromCoordinates();
                    end
                else
                    app.imgavg = (app.imgavg * (k-1) + img) / k;
                end
                
                if mod(k, 2) == 1
                    app.latestOddImg = img; 
                    oddCount = ceil(k/2);
                    if isempty(app.imgavg_odd)
                        app.imgavg_odd = img;
                    else
                        app.imgavg_odd = (app.imgavg_odd * (oddCount-1) + img) / oddCount;
                    end
                else
                    app.latestEvenImg = img; 
                end
                
                if ~isempty(app.masklist)
                    counts = zeros(app.sites, 1);
                    for s = 1:app.sites
                        counts(s) = sum(img(app.masklist(:,:,s)), 'all');
                    end
                    app.photonn(:, k) = counts;
                end
                
                if mod(k, 5) == 0 || k == totalFiles
                    app.ProgressBar.Text = sprintf('进度: %d / %d', k, totalFiles);
                    drawnow limitrate;
                end
            end
            app.processedFileCount = totalFiles;
            
            if isempty(app.masklist)
                app.updateImageDisplays(); 
                if strcmp(app.ROIModeDropDown.Value, '自动')
                    app.autoGetROI();
                    if ~isempty(app.masklist), app.recalculateAllPhotons(); end
                end
            end
            
            if ~isempty(app.photonn)
                if k > 5 && (isempty(app.threshold) || app.threshold == 0)
                    app.calculateAutoThreshold();
                end
                app.updateResults();
                app.updateSingleSiteDistribution(); 
                app.updateSingleSiteSurvival();
                app.updateImageDisplays();
            end
            
            if ~app.AutoProcessCheckBox.Value
                app.StatusLabel.Text = '状态: 处理完成';
                app.ProcessButton.Enable = 'on';
                app.StopButton.Enable = 'off';
                app.FitGaussianButton.Enable = 'on';
            end
        end
        
        function recalculateAllPhotons(app)
            app.StatusLabel.Text = '状态: 基于新ROI重算...';
            numFiles = app.processedFileCount;
            app.photonn = zeros(app.sites, numFiles);
            for k = 1:numFiles
                try
                    img = double(imread(fullfile(app.tifFiles(k).folder, app.tifFiles(k).name))) - 800;
                    img(img < 0) = 0;
                    for s = 1:app.sites
                        app.photonn(s, k) = sum(img(app.masklist(:,:,s)), 'all');
                    end
                catch
                end
            end
        end
        
        function autoGetROI(app)
            if isempty(app.imgavg_odd), return; end
            C = app.imgavg_odd;
            Th = 2 * sum(C(1:3,1:3), 'all') / 8; 
            if Th==0, Th=10; end
            imth = bwareaopen(C > Th, 1);
            [Reg, N] = bwlabel(imth, 8);
            z = regionprops(Reg, 'Centroid', 'Area');
            cnt = 0; s = [];
            for i = 1:N
                if z(i).Area > 1, cnt = cnt+1; s(cnt, :) = z(i).Centroid; end
            end
            if ~isempty(s)
                app.roiCoordinates = round(s);
                app.sites = size(s, 1);
                app.SitesField.Value = app.sites;
                app.createMaskFromCoordinates();
                app.StatusLabel.Text = sprintf('状态: 自动检测 %d ROI', size(s,1));
            end
        end
        
        function createMaskFromCoordinates(app)
            if isempty(app.roiCoordinates) || isempty(app.imgavg), return; end
            [X, Y] = meshgrid(1:size(app.imgavg, 2), 1:size(app.imgavg, 1));
            
            radius = app.ROIRadiusField.Value;
            if radius <= 0, radius = 0.1; end 
            
            n = size(app.roiCoordinates, 1);
            app.masklist = false([size(app.imgavg), n]);
            for i = 1:n
                app.masklist(:,:,i) = sqrt((X - app.roiCoordinates(i,1)).^2 + (Y - app.roiCoordinates(i,2)).^2) <= radius;
            end
            app.mask = sum(app.masklist, 3);
        end
        
        function manualSelectROI(app)
            app.sites = app.SitesField.Value;
            f = figure('Name', sprintf('手动选择 %d 个ROI (按Enter结束)', app.sites), ...
                'NumberTitle', 'off', 'MenuBar', 'none');
            imagesc(app.imgavg_odd, [app.colorMin, app.colorMax]); 
            colormap('hot'); 
            axis image;
            [x, y] = ginput(app.sites);
            if ~isempty(x)
                app.roiCoordinates = round([x, y]);
                app.sites = size(app.roiCoordinates, 1);
                app.SitesField.Value = app.sites; 
                app.createMaskFromCoordinates();
                close(f);
                app.displayROIsOnImage();
                if app.processedFileCount > 0
                    app.recalculateAllPhotons();
                    app.updateResults();
                end
            elseif ishandle(f)
                close(f); 
            end
        end
        
        function displayROIsOnImage(app)
            if ~isempty(app.roiHandles)
                delete(app.roiHandles); 
                app.roiHandles = []; 
            end
            if isempty(app.roiCoordinates), return; end
            
            targets = [app.AvgImageAxes];
            radius = app.ROIRadiusField.Value;
            
            for ax = targets
                hold(ax, 'on');
                h1 = plot(ax, app.roiCoordinates(:,1), app.roiCoordinates(:,2), 'r+', 'MarkerSize', 8);
                app.roiHandles = [app.roiHandles; h1];
                
                for i = 1:size(app.roiCoordinates, 1)
                    h2 = viscircles(ax, app.roiCoordinates(i,:), radius, 'Color', 'r', 'LineWidth', 0.5);
                    app.roiHandles = [app.roiHandles; h2];
                end
                hold(ax, 'off');
            end
        end
        
        function updateImageDisplays(app)
            if ~isempty(app.latestOddImg)
                imagesc(app.LatestOddAxes, app.latestOddImg, [app.colorMin, app.colorMax]);
                title(app.LatestOddAxes, '最新奇数图像 (Load)');
                colormap(app.LatestOddAxes, 'hot'); 
                colorbar(app.LatestOddAxes); 
                axis(app.LatestOddAxes, 'image');
            end
            
            if ~isempty(app.latestEvenImg)
                imagesc(app.LatestEvenAxes, app.latestEvenImg, [app.colorMin, app.colorMax]);
                title(app.LatestEvenAxes, '最新偶数图像 (Survive)');
                colormap(app.LatestEvenAxes, 'hot'); 
                colorbar(app.LatestEvenAxes); 
                axis(app.LatestEvenAxes, 'image');
            end
            
            if ~isempty(app.imgavg_odd)
                imagesc(app.AvgImageAxes, app.imgavg_odd, [app.colorMin, app.colorMax]);
                title(app.AvgImageAxes, '平均图像 (ROI辅助)');
                colormap(app.AvgImageAxes, 'hot'); 
                colorbar(app.AvgImageAxes); 
                axis(app.AvgImageAxes, 'image');
            end
            
            if ~isempty(app.roiCoordinates)
                app.displayROIsOnImage(); 
            end
        end
        
        function calculateAutoThreshold(app)
            if isempty(app.photonn), return; end
            plist = app.photonn(:);
            if max(plist) < 10, return; end
            
            cla(app.TotalDistAxes);
            histogram(app.TotalDistAxes, plist, 60, 'Normalization', 'pdf', 'FaceColor', [.7 .7 .9]);
            hold(app.TotalDistAxes, 'on');
            
            try
                gm = fitgmdist(plist, 2, 'RegularizationValue', 1e-6, 'Replicates', 3);
                mu = sort(gm.mu);
                ctrs = linspace(min(plist), max(plist), 500);
                yfit = pdf(gm, ctrs');
                
                plot(app.TotalDistAxes, ctrs, yfit, 'r-', 'LineWidth', 2);
                
                maskR = (ctrs > mu(1)) & (ctrs < mu(2));
                if any(maskR)
                    [~, midx] = min(yfit(maskR));
                    seg = ctrs(maskR);
                    app.threshold = seg(midx);
                else
                    app.threshold = mean(mu); 
                end
                app.ThresholdField.Value = app.threshold;
                
                xline(app.TotalDistAxes, app.threshold, '--b', 'LineWidth', 2, 'Label', 'Threshold');
                xline(app.TotalDistAxes, mu(1), ':g', 'LineWidth', 2, 'Label', 'Peak 0');
                xline(app.TotalDistAxes, mu(2), ':g', 'LineWidth', 2, 'Label', 'Peak 1');
                
                title(app.TotalDistAxes, sprintf('总分布 (Th: %.1f)', app.threshold));
            catch
                title(app.TotalDistAxes, '总分布 (拟合失败)');
            end
            hold(app.TotalDistAxes, 'off');
        end
        
        function updateSingleSiteDistribution(app)
            if isempty(app.photonn), return; end
            
            siteIdx = round(app.SiteSelectorField.Value);
            if siteIdx < 1 || siteIdx > app.sites
                return; 
            end
            
            data = app.photonn(siteIdx, :);
            cla(app.SingleDistAxes);
            histogram(app.SingleDistAxes, data, 30, 'FaceColor', [.4 .7 .4]);
            xlabel(app.SingleDistAxes, '光子数');
            ylabel(app.SingleDistAxes, '计数');
            title(app.SingleDistAxes, sprintf('点阵 %d 分布', siteIdx));
            xline(app.SingleDistAxes, app.ThresholdField.Value, '--r');
        end
        
        function updateSingleSiteSurvival(app)
            if isempty(app.siteSurvivalRates), return; end
            
            siteIdx = round(app.SurvivalSiteSelectorField.Value);
            if siteIdx < 1 || siteIdx > app.sites
                return; 
            end
            
            validData = ~isnan(app.siteSurvivalRates(siteIdx, :));
            if ~any(validData), return; end
            
            cla(app.SiteSurvivalAxes);
            
            if ~isempty(app.siteSurvivalErrors)
                errorbar(app.SiteSurvivalAxes, ...
                    app.survivalX(validData), ...
                    app.siteSurvivalRates(siteIdx, validData), ...
                    app.siteSurvivalErrors(siteIdx, validData), ...
                    'bo-', 'LineWidth', 1.5);
            else
                plot(app.SiteSurvivalAxes, ...
                    app.survivalX(validData), ...
                    app.siteSurvivalRates(siteIdx, validData), ...
                    'bo-', 'LineWidth', 1.5);
            end
            
            ylim(app.SiteSurvivalAxes, [-0.1 1.1]);
            xlabel(app.SiteSurvivalAxes, 'Variable');
            ylabel(app.SiteSurvivalAxes, 'Survival Rate');
            grid(app.SiteSurvivalAxes, 'on');
            title(app.SiteSurvivalAxes, sprintf('Site %d Survival', siteIdx));
        end
        
        % --- 智能获取阵列维度 ---
        function [nRows, nCols] = getArrayDimensions(app)
            nCols = ceil(sqrt(app.sites));
            nRows = ceil(app.sites / nCols);
            
            if ~isempty(app.roiCoordinates)
                try
                    Y = app.roiCoordinates(:, 2);
                    sortedY = sort(Y);
                    diffY = diff(sortedY);
                    
                    rowThreshold = app.ROIRadiusField.Value * 2; 
                    if rowThreshold == 0, rowThreshold = 5; end
                    
                    detectedRows = sum(diffY > rowThreshold) + 1;
                    
                    if detectedRows > 0 && detectedRows <= app.sites
                        nRows = detectedRows;
                        nCols = ceil(app.sites / nRows);
                    end
                catch
                end
            end
        end
        
        % --- 更新结果 ---
        function updateResults(app)
            numFiles = size(app.photonn, 2);
            app.threshold = app.ThresholdField.Value;
            
            % === 装载率分析 ===
            oddIdx = 1:2:numFiles;
            if ~isempty(oddIdx)
                loadedMat = app.photonn(:, oddIdx) >= app.threshold;
                app.loadingRate_odd = mean(loadedMat, 1);
                
                plot(app.LoadingHistoryAxes, 1:length(app.loadingRate_odd), app.loadingRate_odd*100, 'o-');
                ylim(app.LoadingHistoryAxes, [0 100]); 
                grid(app.LoadingHistoryAxes, 'on');
                xlabel(app.LoadingHistoryAxes, '图像序列'); 
                ylabel(app.LoadingHistoryAxes, '装载率(%)');
                title(app.LoadingHistoryAxes, '所有奇数图像装载率');
                
                app.LoadingRateLabel.Text = sprintf('装载率: %.1f%%', mean(app.loadingRate_odd)*100);
                
                app.loadingRate_site = mean(loadedMat, 2);
                bar(app.SiteLoadingAxes, 1:app.sites, app.loadingRate_site*100);
                ylim(app.SiteLoadingAxes, [0 100]); 
                xlabel(app.SiteLoadingAxes, 'Site Index'); 
                ylabel(app.SiteLoadingAxes, '装载率(%)');
                title(app.SiteLoadingAxes, '所有点装载率');
                
                rates = app.loadingRate_site * 100;
                [nRows, nCols] = app.getArrayDimensions();
                
                if length(rates) < nRows*nCols
                    rates = [rates; nan(nRows*nCols - length(rates), 1)];
                end
                
                heatmapMat = reshape(rates(1:nRows*nCols), nCols, nRows)';
                
                imagesc(app.LoadingHeatmapAxes, heatmapMat);
                colormap(app.LoadingHeatmapAxes, 'hot');
                colorbar(app.LoadingHeatmapAxes);
                
                minRate = min(rates);
                maxRate = max(rates);
                if isempty(minRate), minRate=0; end
                if isempty(maxRate), maxRate=100; end
                if minRate == maxRate, maxRate = minRate + 1e-3; end 
                caxis(app.LoadingHeatmapAxes, [minRate maxRate]);
                
                title(app.LoadingHeatmapAxes, sprintf('装载率热图 [Shape: %dx%d]', nRows, nCols));
                axis(app.LoadingHeatmapAxes, 'equal', 'tight');
                
                app.LoadingHeatmapAxes.XTick = 1:nCols;
                app.LoadingHeatmapAxes.YTick = 1:nRows;
            end
            
            % === 存活率分析 ===
            repeats = app.RepeatsField.Value;
            nPairs = floor(numFiles / 2);
            if nPairs < 1, return; end
            
            p1 = app.photonn(:, 1:2:2*nPairs);
            p2 = app.photonn(:, 2:2:2*nPairs);
            survived = (p2 >= app.threshold) & (p1 >= app.threshold);
            loaded = p1 >= app.threshold;
            
            nGroups = floor(size(p1, 2) / repeats);
            if nGroups > 0
                gSurv = zeros(1, nGroups);
                gErr = zeros(1, nGroups);
                
                app.siteSurvivalRates = zeros(app.sites, nGroups);
                app.siteSurvivalErrors = zeros(app.sites, nGroups);
                
                for g = 1:nGroups
                    idxS = (g-1)*repeats + 1;
                    idxE = g*repeats;
                    
                    % 总体存活率
                    tot_L = sum(loaded(:, idxS:idxE), 'all');
                    tot_S = sum(survived(:, idxS:idxE), 'all');
                    if tot_L > 0
                        p = tot_S / tot_L;
                        gSurv(g) = p;
                        gErr(g) = sqrt(p*(1-p)/tot_L);
                    end
                    
                    % 每个点阵的存活率
                    for s = 1:app.sites
                        site_L = sum(loaded(s, idxS:idxE), 'all');
                        site_S = sum(survived(s, idxS:idxE), 'all');
                        if site_L > 0
                            p_site = site_S / site_L;
                            app.siteSurvivalRates(s, g) = p_site;
                            app.siteSurvivalErrors(s, g) = sqrt(p_site*(1-p_site)/site_L);
                        else
                            app.siteSurvivalRates(s, g) = NaN;
                            app.siteSurvivalErrors(s, g) = NaN;
                        end
                    end
                end
                
                app.survivalRate = gSurv;
                app.survivalError = gErr;
                
                vStart = app.VarStartField.Value;
                vStep = app.VarStepField.Value;
                app.survivalX = vStart + (0:nGroups-1) * vStep;
                
                % 绘制总体存活率
                cla(app.SurvivalAxes);
                errorbar(app.SurvivalAxes, app.survivalX, gSurv, gErr, 'bo-', 'LineWidth', 1.5);
                ylim(app.SurvivalAxes, [-0.1 1.1]);
                xlabel(app.SurvivalAxes, 'Variable');
                ylabel(app.SurvivalAxes, 'Survival Rate');
                grid(app.SurvivalAxes, 'on');
                title(app.SurvivalAxes, sprintf('Overall Survival (Groups: %d)', nGroups));
                app.SurvivalRateLabel.Text = sprintf('存活率: %.2f', gSurv(end));
                
                if app.AutoProcessCheckBox.Value
                    hFits = findobj(app.SurvivalAxes, 'Tag', 'FitLine');
                    delete(hFits);
                end
            end
        end
        
        % --- 记忆功能 ---
        function saveSettings(app)
            s.folder = app.FolderPathField.Value;
            s.threshold = app.ThresholdField.Value;
            s.sites = app.SitesField.Value;
            s.repeats = app.RepeatsField.Value;
            s.varStart = app.VarStartField.Value;
            s.varStep = app.VarStepField.Value;
            s.roiMode = app.ROIModeDropDown.Value;
            s.roiRadius = app.ROIRadiusField.Value; 
            s.cMin = app.ColorMinField.Value;
            s.cMax = app.ColorMaxField.Value;
            s.refresh = app.RefreshIntervalField.Value;
            
            try
                save(fullfile(userpath, app.settingsFile), 's');
            catch
            end
        end
        
        function loadSettings(app)
            try
                f = fullfile(userpath, app.settingsFile);
                if exist(f, 'file')
                    load(f, 's');
                    if isfield(s, 'folder'), app.FolderPathField.Value = s.folder; end
                    if isfield(s, 'threshold'), app.ThresholdField.Value = s.threshold; end
                    if isfield(s, 'sites'), app.SitesField.Value = s.sites; end
                    if isfield(s, 'repeats'), app.RepeatsField.Value = s.repeats; end
                    if isfield(s, 'varStart'), app.VarStartField.Value = s.varStart; end
                    if isfield(s, 'varStep'), app.VarStepField.Value = s.varStep; end
                    if isfield(s, 'roiMode'), app.ROIModeDropDown.Value = s.roiMode; end
                    if isfield(s, 'roiRadius'), app.ROIRadiusField.Value = s.roiRadius; end
                    if isfield(s, 'cMin')
                        app.ColorMinField.Value = s.cMin;
                        app.ColorMaxField.Value = s.cMax;
                        app.colorMin = s.cMin; 
                        app.colorMax = s.cMax;
                    end
                    if isfield(s, 'refresh'), app.RefreshIntervalField.Value = s.refresh; end
                end
            catch
            end
        end
        
        function startupFcn(app)
            app.isProcessing = false;
            app.processedFileCount = 0;
            app.colorMin = 0; 
            app.colorMax = 1000;
            app.StatusLabel.Text = '状态: 初始化完成';
            
            app.loadSettings();
            app.sites = app.SitesField.Value;
            
            if ~isempty(app.FolderPathField.Value)
                 app.rootFolder = app.FolderPathField.Value;
            end
        end
    end

    % Component initialization
    methods (Access = private)
        
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 1400 850];
            app.UIFigure.Name = '量子原子阵列处理器 v4.3 (coldkevin 12.4.2025)';
            app.GridLayout = uigridlayout(app.UIFigure, [2, 2]);
            app.GridLayout.ColumnWidth = {300, '1x'};
            app.GridLayout.RowHeight = {'1x', 80};
            
            % --- Control Panel ---
            app.ControlPanel = uipanel(app.GridLayout);
            app.ControlPanel.Title = '控制与参数';
            app.ControlPanel.Layout.Row = 1; 
            app.ControlPanel.Layout.Column = 1;
            app.ControlPanel.Scrollable = 'on';
            
            app.ControlGrid = uigridlayout(app.ControlPanel, [11, 2]);
            app.ControlGrid.RowHeight = {30, 30, 30, 30, 320, 50, 70, 140, 20, 170, '1x'};
            
            % 1. 文件夹
            app.SelectFolderButton = uibutton(app.ControlGrid, 'push', 'Text', '选择文件夹');
            app.SelectFolderButton.ButtonPushedFcn = createCallbackFcn(app, @SelectFolderButtonPushed, true);
            app.FolderPathField = uieditfield(app.ControlGrid, 'text', 'Placeholder', '路径...');
            
            % 2. 运行
            app.ProcessButton = uibutton(app.ControlGrid, 'push', 'Text', '开始处理', 'BackgroundColor', [.47 .67 .19]);
            app.ProcessButton.ButtonPushedFcn = createCallbackFcn(app, @ProcessButtonPushed, true);
            app.StopButton = uibutton(app.ControlGrid, 'push', 'Text', '停止', 'Enable', 'off', 'BackgroundColor', [.85 .33 .10]);
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            
            app.AutoProcessCheckBox = uicheckbox(app.ControlGrid, 'Text', '自动监控');
            app.AutoProcessCheckBox.Layout.Column = [1 2];
            app.AutoProcessCheckBox.ValueChangedFcn = createCallbackFcn(app, @AutoProcessCheckBoxValueChanged, true);
            
            app.RefreshIntervalLabel = uilabel(app.ControlGrid, 'Text', '刷新(s):');
            app.RefreshIntervalField = uieditfield(app.ControlGrid, 'numeric', 'Value', 2);
            
            % 3. 参数面板
            app.ParametersPanel = uipanel(app.ControlGrid, 'Title', '实验参数');
            app.ParametersPanel.Layout.Row = 5; 
            app.ParametersPanel.Layout.Column = [1 2];
            
            pGrid = uigridlayout(app.ParametersPanel, [6, 2]); 
            pGrid.RowHeight = {30, 30, 30, 30, 30, 30};
            
            uilabel(pGrid, 'Text', '阈值:');
            app.ThresholdField = uieditfield(pGrid, 'numeric', 'Value', 270);
            app.AutoThresholdButton = uibutton(pGrid, 'push', 'Text', '自动算阈值');
            app.AutoThresholdButton.Layout.Column = [1 2];
            app.AutoThresholdButton.ButtonPushedFcn = createCallbackFcn(app, @AutoThresholdButtonPushed, true);
            
            uilabel(pGrid, 'Text', '位点数(Sites):');
            app.SitesField = uieditfield(pGrid, 'numeric', 'Value', 20, 'Limits', [1 Inf]);
            
            uilabel(pGrid, 'Text', '重复次数:');
            app.RepeatsField = uieditfield(pGrid, 'numeric', 'Value', 2);
            
            uilabel(pGrid, 'Text', 'ROI半径:');
            app.ROIRadiusField = uieditfield(pGrid, 'numeric', 'Value', 2);
            
            uilabel(pGrid, 'Text', '变量Start:');
            app.VarStartField = uieditfield(pGrid, 'numeric', 'Value', 84.4);
            uilabel(pGrid, 'Text', '变量Step:');
            app.VarStepField = uieditfield(pGrid, 'numeric', 'Value', 0.0002);
            
            % 4. ROI 操作
            app.ROIControlsGrid = uigridlayout(app.ControlGrid, [2, 2]);
            app.ROIControlsGrid.Layout.Row = 7; 
            app.ROIControlsGrid.Layout.Column = [1 2];
            app.ROIControlsGrid.RowHeight = {30, 30};
            app.ROIControlsGrid.Padding = [0 0 0 0];
            
            app.ROIModeLabel = uilabel(app.ROIControlsGrid, 'Text', 'ROI模式:');
            app.ROIModeDropDown = uidropdown(app.ROIControlsGrid, 'Items', {'自动', '手动'}, 'Value', '自动');
            app.SelectROIButton = uibutton(app.ROIControlsGrid, 'push', 'Text', '手动选ROI');
            app.SelectROIButton.ButtonPushedFcn = createCallbackFcn(app, @SelectROIButtonPushed, true);
            app.ClearROIButton = uibutton(app.ROIControlsGrid, 'push', 'Text', '清除ROI');
            app.ClearROIButton.ButtonPushedFcn = createCallbackFcn(app, @ClearROIButtonPushed, true);
            
            % 5. 图像显示设置
            app.ImageProcessPanel = uipanel(app.ControlGrid, 'Title', '图像显示');
            app.ImageProcessPanel.Layout.Row = 8; 
            app.ImageProcessPanel.Layout.Column = [1 2];
            iGrid = uigridlayout(app.ImageProcessPanel, [2, 2]);
            app.ColorMinLabel = uilabel(iGrid, 'Text', 'Min:');
            app.ColorMinField = uieditfield(iGrid, 'numeric', 'Value', 0);
            app.ColorMaxLabel = uilabel(iGrid, 'Text', 'Max:');
            app.ColorMaxField = uieditfield(iGrid, 'numeric', 'Value', 1000);
            app.AutoScaleButton = uibutton(iGrid, 'push', 'Text', 'Auto');
            app.AutoScaleButton.ButtonPushedFcn = createCallbackFcn(app, @AutoScaleButtonPushed, true);
            app.ApplyScaleButton = uibutton(iGrid, 'push', 'Text', 'Apply');
            app.ApplyScaleButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyScaleButtonPushed, true);
            
            % 6. 导入/导出面板 (新增导入数据按钮)
            app.ExportPanel = uipanel(app.ControlGrid, 'Title', '导入/导出');
            app.ExportPanel.Layout.Row = 10; 
            app.ExportPanel.Layout.Column = [1 2];
            eGrid = uigridlayout(app.ExportPanel, [3, 2]);
            eGrid.RowHeight = {30, 30, 30};
            
            % 导入数据按钮 (新增，放在第一行突出显示)
            app.ImportDataButton = uibutton(eGrid, 'push', 'Text', '导入数据');
            app.ImportDataButton.ButtonPushedFcn = createCallbackFcn(app, @ImportDataButtonPushed, true);
            
            app.ExportDataButton = uibutton(eGrid, 'push', 'Text', '导出数据(mat)');
            app.ExportDataButton.ButtonPushedFcn = createCallbackFcn(app, @ExportDataButtonPushed, true);
            
            app.ExportFiguresButton = uibutton(eGrid, 'push', 'Text', '导出图像');
            app.ExportFiguresButton.ButtonPushedFcn = createCallbackFcn(app, @ExportFiguresButtonPushed, true);
            
            app.ImportROIButton = uibutton(eGrid, 'push', 'Text', '导入ROI');
            app.ImportROIButton.ButtonPushedFcn = createCallbackFcn(app, @ImportROIButtonPushed, true);
            
            app.ExportROIButton = uibutton(eGrid, 'push', 'Text', '导出ROI');
            app.ExportROIButton.ButtonPushedFcn = createCallbackFcn(app, @ExportROIButtonPushed, true);
            
            % --- Display Tabs ---
            app.DisplayTabGroup = uitabgroup(app.GridLayout);
            app.DisplayTabGroup.Layout.Row = 1; 
            app.DisplayTabGroup.Layout.Column = 2;
            
            % 1. Preview
            app.PreviewTab = uitab(app.DisplayTabGroup, 'Title', '实时预览');
            previewGrid = uigridlayout(app.PreviewTab, [1, 2]);
            app.LatestOddAxes = uiaxes(previewGrid);
            app.LatestEvenAxes = uiaxes(previewGrid);
            
            % 2. Loading
            app.LoadingTab = uitab(app.DisplayTabGroup, 'Title', '装载率分析');
            loadingGrid = uigridlayout(app.LoadingTab, [2, 2]);
            app.LoadingHistoryAxes = uiaxes(loadingGrid);
            app.LoadingHistoryAxes.Layout.Row = 1;
            app.LoadingHistoryAxes.Layout.Column = [1 2];
            app.SiteLoadingAxes = uiaxes(loadingGrid);
            app.SiteLoadingAxes.Layout.Row = 2;
            app.SiteLoadingAxes.Layout.Column = 1;
            app.LoadingHeatmapAxes = uiaxes(loadingGrid);
            app.LoadingHeatmapAxes.Layout.Row = 2;
            app.LoadingHeatmapAxes.Layout.Column = 2;
            
            % 3. Survival
            app.SurvivalTab = uitab(app.DisplayTabGroup, 'Title', '存活率');
            app.SurvivalGrid = uigridlayout(app.SurvivalTab, [3, 1]);
            app.SurvivalGrid.RowHeight = {40, '1x', '1x'};
            
            % 控制组件
            app.SurvivalControlGrid = uigridlayout(app.SurvivalGrid, [1, 6]);
            app.SurvivalControlGrid.Layout.Row = 1;
            app.SurvivalControlGrid.ColumnWidth = {100, 60, 150, 80, 60, '1x'};
            
            app.SurvivalSiteSelectorLabel = uilabel(app.SurvivalControlGrid, 'Text', '选择点阵:');
            app.SurvivalSiteSelectorField = uieditfield(app.SurvivalControlGrid, 'numeric', 'Value', 1, 'Limits', [1 Inf]);
            app.SurvivalSiteSelectorField.ValueChangedFcn = createCallbackFcn(app, @SurvivalSiteSelectorValueChanged, true);
            
            app.ShowAllSiteSurvivalButton = uibutton(app.SurvivalControlGrid, 'push', 'Text', '显示所有点阵');
            app.ShowAllSiteSurvivalButton.ButtonPushedFcn = createCallbackFcn(app, @ShowAllSiteSurvivalButtonPushed, true);
            
            app.FitGaussianButton = uibutton(app.SurvivalControlGrid, 'push', 'Text', '高斯拟合');
            app.FitGaussianButton.ButtonPushedFcn = createCallbackFcn(app, @FitGaussianButtonPushed, true);
            
            uilabel(app.SurvivalControlGrid, 'Text', '');
            
            app.FitStatusLabel = uilabel(app.SurvivalControlGrid, 'Text', '');
            
            % 总体存活率图
            app.SurvivalAxes = uiaxes(app.SurvivalGrid);
            app.SurvivalAxes.Layout.Row = 2;
            title(app.SurvivalAxes, 'Overall Survival');
            
            % 单点阵存活率图
            app.SiteSurvivalAxes = uiaxes(app.SurvivalGrid);
            app.SiteSurvivalAxes.Layout.Row = 3;
            title(app.SiteSurvivalAxes, 'Individual Site Survival');
            
            % 4. Bimodal
            app.BimodalTab = uitab(app.DisplayTabGroup, 'Title', '双峰分布');
            app.BimodalGrid = uigridlayout(app.BimodalTab, [3, 1]);
            app.BimodalGrid.RowHeight = {40, '1x', '1x'};
            
            app.BimodalControlsGrid = uigridlayout(app.BimodalGrid, [1, 4]);
            app.BimodalControlsGrid.Layout.Row = 1;
            app.BimodalControlsGrid.ColumnWidth = {80, 60, 150, '1x'};
            
            app.SiteSelectorLabel = uilabel(app.BimodalControlsGrid, 'Text', '选择点阵:');
            app.SiteSelectorField = uieditfield(app.BimodalControlsGrid, 'numeric', 'Value', 1, 'Limits', [1 Inf]);
            app.SiteSelectorField.ValueChangedFcn = createCallbackFcn(app, @SiteSelectorValueChanged, true);
            
            app.ShowAllSitesButton = uibutton(app.BimodalControlsGrid, 'push', 'Text', '显示所有点阵分布');
            app.ShowAllSitesButton.ButtonPushedFcn = createCallbackFcn(app, @ShowAllSitesButtonPushed, true);
            
            app.TotalDistAxes = uiaxes(app.BimodalGrid);
            app.TotalDistAxes.Layout.Row = 2;
            title(app.TotalDistAxes, '总分布');
            
            app.SingleDistAxes = uiaxes(app.BimodalGrid);
            app.SingleDistAxes.Layout.Row = 3;
            title(app.SingleDistAxes, '单点阵分布');
            
            % 5. Avg Image
            app.AvgImageTab = uitab(app.DisplayTabGroup, 'Title', 'ROI辅助');
            avgGrid = uigridlayout(app.AvgImageTab, [2, 1]); 
            avgGrid.RowHeight = {'1x', 40};
            app.AvgImageAxes = uiaxes(avgGrid);
            app.AvgImageAxes.Layout.Row = 1;
            app.UpdateAvgImageButton = uibutton(avgGrid, 'push', 'Text', '刷新平均图');
            app.UpdateAvgImageButton.Layout.Row = 2;
            app.UpdateAvgImageButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateAvgImageButtonPushed, true);
            
            % 6. Info Tab
            app.InfoTab = uitab(app.DisplayTabGroup, 'Title', '实验信息');
            app.InfoGrid = uigridlayout(app.InfoTab, [2, 1]);
            app.InfoGrid.RowHeight = {40, '1x'};
            
            infoControlGrid = uigridlayout(app.InfoGrid, [1, 2]);
            infoControlGrid.Layout.Row = 1;
            infoControlGrid.ColumnWidth = {150, '1x'};
            
            app.LoadH5Button = uibutton(infoControlGrid, 'push', 'Text', '加载 H5 参数文件');
            app.LoadH5Button.ButtonPushedFcn = createCallbackFcn(app, @LoadH5ButtonPushed, true);
            
            app.H5PathLabel = uilabel(infoControlGrid, 'Text', '未选择文件');
            
            app.InfoTextArea = uitextarea(app.InfoGrid);
            app.InfoTextArea.Layout.Row = 2;
            app.InfoTextArea.Editable = 'off';
            app.InfoTextArea.FontName = 'Consolas'; 
            app.InfoTextArea.FontSize = 12;

            % --- Status Bar ---
            app.StatusPanel = uipanel(app.GridLayout, 'Title', '状态');
            app.StatusPanel.Layout.Row = 2; 
            app.StatusPanel.Layout.Column = [1 2];
            stGrid = uigridlayout(app.StatusPanel, [1, 4]);
            app.StatusLabel = uilabel(stGrid, 'Text', '就绪');
            app.ProgressBar = uilabel(stGrid, 'Text', '进度: 0%');
            app.LoadingRateLabel = uilabel(stGrid, 'Text', '装载率: --', 'FontWeight', 'bold');
            app.SurvivalRateLabel = uilabel(stGrid, 'Text', '存活率: --', 'FontWeight', 'bold');
            
            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)
        function app = QuantumAtomProcessor
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end
        
        function delete(app)
            app.saveSettings();
            if ~isempty(app.autoProcessTimer) && isvalid(app.autoProcessTimer)
                stop(app.autoProcessTimer); 
                delete(app.autoProcessTimer);
            end
            delete(app.UIFigure)
        end
    end
end