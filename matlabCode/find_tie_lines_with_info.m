function [tie_lines, tie_info] = find_tie_lines_with_info(mpc)
    % FIND_TIE_LINES_WITH_INFO 识别联络线并返回附加信息
    %
    % 输出参数:
    %   tie_lines - 联络线数据矩阵
    %   tie_info - 包含联络线详细信息的结构数组
    
    % 调用基本函数获取联络线
    tie_lines = find_tie_lines(mpc);
    
    % 初始化附加信息结构
    tie_info = struct('from_bus', {}, 'to_bus', {}, ...
                     'from_area', {}, 'to_area', {}, ...
                     'impedance', {}, 'capacity', {});
    
    % 建立节点到区域的映射
    bus_area_dict = containers.Map(mpc.bus(:,1), mpc.bus(:,7));
    
    % 填充附加信息
    for i = 1:size(tie_lines, 1)
        fbus = tie_lines(i, 1);
        tbus = tie_lines(i, 2);
        
        tie_info(i).from_bus = fbus;
        tie_info(i).to_bus = tbus;
        tie_info(i).from_area = bus_area_dict(fbus);
        tie_info(i).to_area = bus_area_dict(tbus);
        tie_info(i).impedance = complex(tie_lines(i, 3), tie_lines(i, 4));
        tie_info(i).capacity = tie_lines(i, 6); % rateA作为容量
    end
end