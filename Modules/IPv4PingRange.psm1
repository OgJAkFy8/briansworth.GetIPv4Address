function Ping-IpRange
{
  <#
      .SYNOPSIS
      Tests a range of Ip addresses.

      .DESCRIPTION
      A simple function to test a range of Ip addresses and returns the results to the screen. It returns an object, so you can sort and filter.

      .PARAMETER FirstAddress
      First address to test.

      .PARAMETER LastAddress
      Last address to test.

      .EXAMPLE
      Ping-IpRange -FirstAddress 192.168.0.20 -LastAddress 192.168.0.25 | sort available

      Address      Available
      -------      ---------
      192.168.0.22     False
      192.168.0.23     False
      192.168.0.25     False
      192.168.0.20      True
      192.168.0.21      True
      192.168.0.24      True
    
      .EXAMPLE
      Ping-IpRangeNew -FirstAddress 192.168.0.20 -LastAddress 192.168.0.50 | Where Available -EQ $true

      Address      Available
      -------      ---------
      192.168.0.20      True
      192.168.0.21      True
      192.168.0.24      True
      192.168.0.43      True


      .OUTPUTS
      Object to console
  #>
  [CmdletBinding()]
  [Alias("pingr")]
  Param(
    [Parameter(Mandatory,HelpMessage = 'Ip Address to start from',Position = 0)]
    [ipaddress]$FirstAddress,
    [Parameter(Mandatory,HelpMessage = 'Ip Address to stop at',Position = 1)]
    [ipaddress]$LastAddress
  )

  $Startip = ConvertIPv4ToInt -IPv4Address $FirstAddress.IPAddressToString
  $endip = ConvertIPv4ToInt -IPv4Address $LastAddress.IPAddressToString
  $PingRange = @()
    
  Try
  {
    $ProgressCount = $endip - $Startip
    $j = 0
    for($i = $Startip;$i -le $endip;$i++)
    {
      $ip = ConvertIntToIPv4 -Integer $i
      $Response = [PSCustomObject]@{
        Address   = $ip
        Available = (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeToLive 20)
      }

      Write-Progress -Activity ('Ping {0}' -f $ip) -PercentComplete ($j / $ProgressCount*100)
      $j++

      $PingRange += $Response
    }
  }
  Catch
  {
    Write-Error -Exception $_.Exception -Category $_.CategoryInfo.Category
  }
  $PingRange
}

function Find-MTUSize 
{
  <#
      .SYNOPSIS
      Returns the MTU size on your network

      .DESCRIPTION
      This automates the manual ping test, guess, subtract, test, guess, test again

      .PARAMETER IpToPing
      IP Address to test against. An example is your gateway

      .EXAMPLE
      Get-MTU -IpToPing 192.168.0.1
      Will ping the ip and return the MTU size

      .NOTES
      The program adds 28 to the final number to account for 20 bytes for the IP header and 8 bytes for the ICMP Echo Request header

      .LINK
      URLs to related sites
      The first link is opened by Get-Help -Online Get-MTU

      .INPUTS
      IP Address as an ipaddress

      .OUTPUTS
      MTU as an Object
  #>


  param(
    [Parameter(Mandatory = $true,HelpMessage = 'IP Address to test against. An example is your gateway')]
    [ipaddress]$IpToPing
  )
  Begin{
    [int]$Script:UpperBoundPacketSize = 9000 #Jumbo Frame 
    $DecrementBy = @(100, 50, 1)
    $IpAddress = $IpToPing.ToString()
    function Test-Size
    {
      <#
          .SYNOPSIS
          Test size of MTU with Ping.exe
      #>

      param
      (
        [Parameter(Mandatory = $true)]
        [String]$IpAddress,

        [Parameter(Mandatory = $true)]
        [int]$UpperBoundPacketSize,

        [Parameter(Mandatory = $true)]
        [int]$DecrementBy
      )
      $PingOut = $null
      $SearchString = '*fragmented*'
      $Script:UpperBoundPacketSize  += $DecrementBy+100
      do 
      {
        $Script:UpperBoundPacketSize -= $DecrementBy
        Write-Verbose -Message ('Testing packet size {0}' -f $Script:UpperBoundPacketSize)
        $PingOut = & "$env:windir\system32\ping.exe" $IpAddress -n 1 -l $Script:UpperBoundPacketSize -f
      }
      while ($PingOut[2] -like $SearchString)
    }
  }
  Process{
    $DecrementBy | ForEach-Object -Process {
      Test-Size -IpAddress $IpAddress -UpperBoundPacketSize $Script:UpperBoundPacketSize -DecrementBy $_
    }
  }
  End{
    $MTU = [int]$Script:UpperBoundPacketSize + 28 # Add 28 to this number to account for 20 bytes for the IP header and 8 bytes for the ICMP Echo Request header
    Remove-Variable -Name UpperBoundPacketSize -Scope Global # This just cleans up the variable since it was in the Global scope
    
    New-Object -TypeName PSObject -Property @{
      MTU = $MTU
  }}
}
