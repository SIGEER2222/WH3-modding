using namespace System.Net.WebSockets
using namespace System.Threading
using namespace System.Text

param(
    [Parameter(Mandatory=$true)] [string]$CommandsFile,
    [Parameter(Mandatory=$true)] [string]$OutputFile,
    [int]$ReceiveTimeoutMs = 60000
)
$ws = [ClientWebSocket]::new()
$ct = [CancellationToken]::None
$ws.ConnectAsync([Uri]'ws://127.0.0.1:45127/ws',$ct).Wait()
function Send($id,$data){
    $body = @{"id"=$id;"data"=$data} | ConvertTo-Json -Depth 20 -Compress
    $buf = [Encoding]::UTF8.GetBytes($body)
    $seg = [ArraySegment[byte]]::new($buf)
    $ws.SendAsync($seg,[WebSocketMessageType]::Text,$true,$ct).Wait()
}
function Recv($timeoutMs){
    $ms = New-Object System.IO.MemoryStream
    $buf = New-Object byte[] 65536
    $seg = [ArraySegment[byte]]::new($buf)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while($sw.ElapsedMilliseconds -lt $timeoutMs){
        $remaining = [Math]::Max(100, $timeoutMs - $sw.ElapsedMilliseconds)
        $t = $ws.ReceiveAsync($seg,$ct)
        if(!$t.Wait($remaining)){ return $null }
        $r = $t.Result
        if($r.MessageType -eq [WebSocketMessageType]::Close){ return $null }
        if($r.Count -gt 0){ $ms.Write($buf,0,$r.Count) }
        if($r.EndOfMessage){ return [Encoding]::UTF8.GetString($ms.ToArray()) }
    }
    return $null
}
$cmds = Get-Content $CommandsFile -Raw | ConvertFrom-Json
$responses = @()
foreach($cmd in $cmds){
    $id = [int]($cmd.id)
    Send $id $cmd.data
    $collected = @()
    while($true){
        $r = Recv $ReceiveTimeoutMs
        if($r -eq $null){ break }
        $collected += $r
        $parsed = $r | ConvertFrom-Json
        if($parsed.id -eq $id){ break }
    }
    $responses += [PSCustomObject]@{ id=$id; responses=$collected }
}
try { $ws.CloseAsync([WebSocketCloseStatus]::NormalClosure,"done",[CancellationToken]::None).Wait() } catch {}
$responses | ConvertTo-Json -Depth 20 -Compress | Out-File -Encoding utf8 $OutputFile
