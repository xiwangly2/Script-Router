<?php
// 处理请求
function handleRequest() {
    $requestSource = getRequestSource();

    if ($requestSource === 'curl' || $requestSource === 'wget') {
        // 获取请求的脚本文件名
        $scriptName = basename($_SERVER['REQUEST_URI']);
        // 构建脚本文件的完整路径
        $scriptPath = 'scripts/' . $scriptName;
//         $scriptPath = $scriptName;

        // 检查是否为根路径
        if ($_SERVER['REQUEST_URI'] === '/') {
            $scriptPath = 'scripts/index.sh';
        }

        // 检查脚本文件是否存在
        if (!file_exists($scriptPath)) {
            http_response_code(404);
            echo "File Not Found";
            return;
        }

        // 读取脚本文件内容
        $scriptContent = file_get_contents($scriptPath);
        if ($scriptContent === false) {
            http_response_code(500);
            echo "Internal Server Error";
            return;
        }

        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . $scriptName . '"');
        echo $scriptContent;
        return;
    }
    elseif ($requestSource === 'powershell') {
        // 获取请求的脚本文件名
        $scriptName = basename($_SERVER['REQUEST_URI']);
        // 构建脚本文件的完整路径
        $scriptPath = 'scripts/' . $scriptName;
//         $scriptPath = $scriptName;

        // 检查是否为根路径
        if ($_SERVER['REQUEST_URI'] === '/') {
            $scriptPath = 'scripts/index.ps1';
        }

        // 检查脚本文件是否存在
        if (!file_exists($scriptPath)) {
            http_response_code(404);
            echo "File Not Found";
            return;
        }

        // 读取脚本文件内容
        $scriptContent = file_get_contents($scriptPath);
        if ($scriptContent === false) {
            http_response_code(500);
            echo "Internal Server Error";
            return;
        }

        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . $scriptName . '"');
        echo $scriptContent;
        return;
    }
    else{
        // 如果是正常浏览器访问，则显示正常的页面
        // echo "<h1>Hello, World!</h1>";
        header('Location: index.html');
    }
}

// 获取请求来源
function getRequestSource() {
    $userAgent = $_SERVER['HTTP_USER_AGENT'];
    if (strpos($userAgent, 'curl') !== false) {
        return 'curl';
    } elseif (strpos($userAgent, 'Wget') !== false) {
        return 'wget';
    } elseif (strpos($userAgent, 'WindowsPowerShell') !== false) {
        return 'powershell';
    }
    return 'browser';
}

// 调用处理请求函数
handleRequest();
?>
