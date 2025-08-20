clc;
clear all;

% 清理可能的旧 UDP 对象
disp('▶step1.清理旧的 UDP 对象......');
instruments = instrfind('Type', 'udp', 'LocalPort', [12345, 12346, 12347, 12348, 12349, 12350,12351]);
if ~isempty(instruments)
    fclose(instruments);
    delete(instruments);
    disp('  清理旧的 UDP 对象');
end
clear instruments;

port = 12350; % 需要释放的端口号
system(['netstat -aon | findstr ' num2str(port)]); % 显示占用该端口的进程信息
system(['taskkill /PID [进程ID] /F']); % 根据需要替换[进程ID]为实际的PID，强制关闭进程

% 检查端口占用
system('netstat -aon | findstr "12345 12346 12347 12348 12349 12350 12351"');
disp('  检查端口占用，若被占用，请终止相关进程');

% UDP 发送端口
disp('▶step2.Matlab[12350]>>Python[12347]:打开与Python的握手控制端口......');
try
    control_sender = udp('127.0.0.1', 12347, 'LocalHost', '127.0.0.1', 'LocalPort', 12350, 'Timeout', 2);
    fopen(control_sender);
    disp(['  Control sender status: ', control_sender.Status]);
    disp(['  Control sender remote: ', control_sender.RemoteHost, ':', num2str(control_sender.RemotePort)]);
    disp(['  Control sender local port: ', num2str(control_sender.LocalPort)]);
    system('  netstat -aon | findstr "12347 12350"');
catch e
    disp(['  Control sender 打开失败: ', e.message]);
    system('  netstat -aon | findstr "12350"');
    disp('  请检查并终止占用 12350 的进程，或更换端口');
    return;
end

% UDP 接收端口
disp('▶step3.Matlab[12348]<<Python[--]:打开与Python的握手确认端口......');
try
    confirm_receiver = udp('127.0.0.1', 'LocalHost', '127.0.0.1', 'LocalPort', 12348, 'Timeout', 10);
    fopen(confirm_receiver);
    disp(['  Confirm receiver status: ', confirm_receiver.Status]);
    disp(['  Confirm receiver local port: ', num2str(confirm_receiver.LocalPort)]);
    system('  netstat -aon | findstr "12348"');
catch e
    disp(['  Confirm receiver 打开失败: ', e.message]);
    if exist('  control_sender', 'var')
        fclose(control_sender);
        delete(control_sender);
    end
    system('  netstat -aon | findstr "12348"');
    return;
end

disp('▶step4.请手动运行启动python代码......');
pause(10);

% 变量初始化
episode = 0;
sim_status = 0;
training_data = struct('gain', {}, 'inputs', {}, 'outputs', {}, 'times', {});

% 发送握手信号 [0, -1]
disp('▶step5.Matlab[12350]>>Python[12347]: 发送握手控制[0.0,-1.0]......');
disp('▶step5.Matlab[12348]<<Python[-----]: 接收握手响应[0.0,-1.0]......');
max_attempts = 5;
attempt = 1;
handshake_received = false;
while attempt <= max_attempts && ~handshake_received
    data = [double(0), double(-1)];
    disp([' 发送字节: ', num2str(typecast(data, 'uint8'), '%d ')]); % 格式化输出
    fwrite(control_sender, typecast(data, 'uint8'), 'uint8');
    disp([' 发送握手信号: Attempt ', num2str(attempt), ', Data: ', num2str(data)]);
    
    tic;
    while toc < 10
        if confirm_receiver.BytesAvailable >= 16
            data = fread(confirm_receiver, 16, 'uint8')'; % 确保行向量
            disp([' 收到原始字节: ', num2str(data, '%d ')]); % 格式化输出
            data_double = typecast(uint8(data), 'double');
            disp([' 收到数据: ', num2str(data_double)]);
            if isequal(data_double, [0, -1])
                handshake_received = true;
                disp(' 收到 Python 握手确认，开始仿真');
                break;
            end
        end
        pause(0.01);
    end
    if ~handshake_received
        disp(['  未收到确认，BytesAvailable: ', num2str(confirm_receiver.BytesAvailable)]);
        system('  netstat -aon | findstr "12348"');
    end
    attempt = attempt + 1;
    pause(0.5);
end

if ~handshake_received
    disp('  未收到握手确认，退出');
    fclose(control_sender);
    delete(control_sender);
    fclose(confirm_receiver);
    delete(confirm_receiver);
    return;
end

disp('▶step6.Matlab与Python握手通信成功！加载car模型，准备开始仿真！');
% 加载模型
load_system('car.slx');
set_param('car', 'SolverType', 'Fixed-step');
set_param('car', 'Solver', 'ode3');
set_param('car','FixedStep', '0.01');
% 假设仿真停止时间为 10 秒
set_param('car', 'StopTime', '10');
pause(1);

% 检查 随机设定模型参数：Gain 块
gain_blocks = find_system('car', 'BlockType', 'Gain');
if isempty(gain_blocks)
    error('  未找到 Gain 块，请检查 car.slx 模型');
else
    disp(['  设置 Gain 模块参数初始值: ', gain_blocks{1}]);
    set_param(gain_blocks{1}, 'Gain', num2str(1));
end



% % 检查 Simulink 端口
% disp('检查 Simulink UDP 端口...');
% try
%     sim('car', 'SimulationMode', 'normal');
%     pause(2);
%     system('netstat -aon | findstr "12345 12346 12347 12348 12349 12350"');
% catch e
%     disp('Simulink 运行错误:');
%     disp(e.message);
%     fclose(control_sender);
%     delete(control_sender);
%     fclose(confirm_receiver);
%     delete(confirm_receiver);
%     close_system('car.slx', 0);
%     return;
% end



% 循环运行 50 次仿真
for iter = 1:50
    episode = episode + 1;
    sim_status = 0;
    
    gain_value = randi([1, 100]);
    set_param(gain_blocks{1}, 'Gain', num2str(gain_value));
    disp(['  Episode = ', num2str(episode), ': Set Random Gain = ', num2str(gain_value)]);
    
    sim_status = 1;
    data = [double(episode), double(sim_status)];
    disp(['    UDP send START status [Simulink >> Python: Episode]: ', num2str(episode), ', Status ', num2str(sim_status)]);
    %disp(['        Show UDP bytes: ', num2str(typecast(data, 'uint8'), '%d ')]); % 格式化输出
    fwrite(control_sender, typecast(data, 'uint8'), 'uint8');
    
    
    try
        disp('    Start this episode simulation...');
        sim_out = sim('car', 'SimulationMode', 'normal', 'ReturnWorkspaceOutputs', 'on');
    
        logs = sim_out.logsout;
        if logs.numElements < 3
            error('✘Simulink logsout wrong number of elements，at least 3 （inputs, outputs, times）');
        end
        training_data(episode).gain = gain_value;
        training_data(episode).inputs = logs.getElement(1).Values;
        training_data(episode).outputs = logs.getElement(2).Values;
        training_data(episode).times = logs.getElement(3).Values;
    catch e
        disp(['✘Simulink Simulation Running Error (Episode ', num2str(episode), '): ', e.message]);
        fclose(control_sender);
        delete(control_sender);
        fclose(confirm_receiver);
        delete(confirm_receiver);
        close_system('car.slx', 0);
        return;
    end
    
    sim_status = 0;
    data = [double(episode), double(sim_status)];
    disp(['    UDP send STOP status [Simulink >> Python: Episode]: ',  num2str(episode), ', Status ', num2str(sim_status)]);
    %disp(['        Show UDP bytes: ',  num2str(typecast(data, 'uint8'), '%d ')]); % 格式化输出
    fwrite(control_sender, typecast(data, 'uint8'), 'uint8');

end

% 发送结束信号 [51, -2]
attempt = 1;
end_received = false;
while attempt <= max_attempts && ~end_received
    data = [double(51), double(-2)];
    disp(['▶step7. Udp send FINAL episode and sim_status: Attempt ', num2str(attempt)]);
    % disp(['       Udp send FINAL episode and sim_status: ', num2str(typecast(data, 'uint8'), '%d ')]); % 格式化输出
    fwrite(control_sender, typecast(data, 'uint8'), 'uint8');

    
    tic;
    while toc < 5
        if confirm_receiver.BytesAvailable >= 16
            data = fread(confirm_receiver, 16, 'uint8')'; % 确保行向量
            %disp(['    UDP receive response from python: ', num2str(data, '%d ')]); % 格式化输出
            data_double = typecast(uint8(data), 'double');
            disp(['    UDP receive response from python: ', num2str(data_double)]);
            if isequal(data_double, [51, -2])
                end_received = true;
                disp('    ✔Confirm the response from Python，FINISH sim successfully!');
                break;
            end
        end
        pause(0.01);
    end
    if ~end_received
        disp(['    ✘ NOT confirm finish，BytesAvailable: ', num2str(confirm_receiver.BytesAvailable)]);
    end
    attempt = attempt + 1;
    pause(0.5);
end

if ~end_received
    disp('    ✘ NOT confirm response from python，FAIL!');
end

% 清理
fclose(control_sender);
fclose(control_sender);
fclose(confirm_receiver);
delete(confirm_receiver);
close_system('car.slx', 0);

disp('▶step8. ✔All the episodes data are saved: training_data in workspace!');