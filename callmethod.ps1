# internal static object CallMethod(Token token, object target, string methodName, object[] paramArray, bool callStatic, object valueToSet)

$call = $( [psobject].Assembly.gettype("System.Management.Automation.ParserOps", $true).getmethods("NonPublic,Static") | ? {$_.name -eq "callmethod"} )

# System.Object Invoke(System.Object obj,
#                      System.Reflection.BindingFlags invokeAttr,
#                      System.Reflection.Binder binder,
#                      System.Object[] parameters,
#                      System.Globalization.CultureInfo culture)

# System.Object Invoke(System.Object obj, System.Object[] parameters)

$automationNull = [System.Management.Automation.Internal.AutomationNull]::Value

<#

$target = [string].UnderlyingSystemType
$methodName = "Format"
$paramArray = @("Hello, {0}.", "Oisin")

trace-command -pshost memberresolution { 
    $call.invoke($null, "NonPublic,Static", $null, @(
        $null, # token
        $target, # target
        $methodName, # method name
        $paramArray, # param array
        $true, # static call
        $automationNull #  value to set (parameterized property, field?)
        ), $null)
}
#>

<#
static PSObject()
{
    memberCollection = GetMemberCollection(PSMemberViewTypes.All);
    methodCollection = GetMethodCollection();
    propertyCollection = GetPropertyCollection(PSMemberViewTypes.All);
    dotNetInstanceAdapter = new DotNetAdapter();
    baseAdapterForAdaptedObjects = new BaseDotNetAdapterForAdaptedObjects();
    dotNetStaticAdapter = new DotNetAdapter(true);
    dotNetInstanceAdapterSet = new AdapterSet(dotNetInstanceAdapter, null);
    ...
#>    

<#

# GetInstanceMethod*, GetInstanceProperty*, GetInstanceEvent*, GetStatic*
private static CacheTable GetInstanceMethodReflectionTable(object obj)
{
    lock (instanceMethodCacheTable)
    {
        CacheTable typeMethods = null;
        Type type = obj.GetType();
        typeMethods = (CacheTable) instanceMethodCacheTable[type];
        if (typeMethods == null)
        {
            typeMethods = new CacheTable();
            PopulateMethodReflectionTable(type, typeMethods, BindingFlags.FlattenHierarchy | BindingFlags.Public | BindingFlags.Instance | BindingFlags.IgnoreCase);
            instanceMethodCacheTable[type] = typeMethods;
        }
        return typeMethods;
    }
}

# PopulateEvent*, PopulateProperty*

private static void PopulateMethodReflectionTable(Type type, CacheTable typeMethods, BindingFlags bindingFlags)
{
    MethodInfo[] methods = type.GetMethods(bindingFlags);
    PopulateMethodReflectionTable(type, methods, typeMethods);
    for (int i = 0; i < typeMethods.memberCollection.Count; i++)
    {
        typeMethods.memberCollection[i] = new MethodCacheEntry((MethodInfo[]) ((ArrayList) typeMethods.memberCollection[i]).ToArray(typeof(MethodInfo)));
    }
}

#>

function Find-Type {
    param(
        [string]$TypeName,
        [reflection.bindingflags]$BindingFlags = "Public,NonPublic",
        [switch]$IncludePowershellAssemblies,
        [switch]$IncludeDotNetAssemblies,
        [switch]$IncludeWPFAssemblies,
        [switch]$CaseSensitive
    )
    
    write-verbose "Searching for $typeName"
    
    $ps = @(
        'CompiledComposition.Microsoft.PowerShell.GPowerShell',
        'Microsoft.PowerShell.Commands.Diagnostics',
        'Microsoft.PowerShell.Commands.Management',
        'Microsoft.PowerShell.Commands.Utility',
        'Microsoft.PowerShell.ConsoleHost',
        'Microsoft.PowerShell.Editor',
        'Microsoft.PowerShell.GPowerShell',
        'Microsoft.PowerShell.Security',
        'Microsoft.WSMan.Management',
        'powershell_ise',
        'PSEventHandler',
        'System.Management.Automation')
        
    $wpf = @(
        'PresentationCore',
        'PresentationFramework', 
        'PresentationFramework.Aero',
        'WindowsBase',
        'UIAutomationProvider',
        'UIAutomationTypes')

    $assemblies = [appdomain]::CurrentDomain.GetAssemblies() | ? {
        (!($_.getname().name -match '(mscorlib|^System$|^System\..*)')) -or $IncludeDotNetAssemblies} | ? {
        (!($ps -contains $_.getname().name)) -or $IncludePowershellAssemblies } | ? {
        (!($wpf -contains $_.getname().name)) -or $IncludeWPFAssemblies }
        
    $matches = @()
    
    $assemblies | % {
        write-verbose "Searching $($_.getname().name)..."
        
        $match = $_.gettype($typename, $false, $CaseSensitive)
        if ($match) {
            $matches += $match
        }        
    }
    
    write-verbose "Found $($matches.length) match(es)."
        
    $matches
}

<#
$iadapter.gettype().getmethods("NonPublic,Instance,Static") | `
    select @{Name="Static";Expression={$_.isstatic}}, `
           @{name="Name"; expression={$_.Name}}, `
           @{Name="Definition"; Expression={$_.tostring()}} | ft -group static -auto
#>

#    DotNetAdapter Fields
# ==========================
# instancePropertyCacheTable
# staticPropertyCacheTable
# instanceMethodCacheTable
# staticMethodCacheTable
# instanceEventCacheTable
# staticEventCacheTable
# instanceBindingFlags
# staticBindingFlags

#$stringCacheTable = $fields[0].getvalue( $dotnetinstanceadapter )[[string]]



$instance = @{}
$instance.adapter = $( [psobject].GetFields("NonPublic,Static")|?{$_.name -eq "dotNetInstanceAdapter"} ).GetValue([psobject])

$instance.adapter.gettype().getfields("NonPublic,Static") | % {
    $instance[$_.name] = $_.getvalue($instance.adapter);
}

$static = @{}
$static.adapter = $( [psobject].GetFields("NonPublic,Static")|?{$_.name -eq "dotNetStaticAdapter"} ).GetValue([psobject])

$static.adapter.gettype().getfields("NonPublic,Static") | % {
    $static[$_.name] = $_.getvalue($static.adapter);
}

$binding = [reflection.bindingflags]

$cacheTableType = [psobject].assembly.gettype("System.Management.Automation.CacheTable")
$populateTableSig = [type[]]([type], $cacheTableType, $binding)

$ipopulate = @{}
$spopulate = @{}

$ipopulate.method = $iadapter.gettype().getmethod("PopulateMethodReflectionTable", "NonPublic,Static", $null, $populateTableSig, @())

$spopulate.method = $sadapter.gettype().getmethod("PopulateMethodReflectionTable", "NonPublic,Static", $null, $populateTableSig, @())

function Get-StaticAdapter {
    $static.adapter
}

function Get-InstanceAdapter {
    $instance.adapter
}

function Get-MemberCacheTable {
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true, position=0)]
        [validatenotnullorempty()]
        [string]$TypeName,

        [parameter(mandatory=$true, position=1)]
        [ValidateSet("Property","Method","Event")]
        [string]$MemberType,

        [parameter()]
        [switch]$Static
    )
    
    $type = Find-Type -TypeName $TypeName -IncludeDotNetAssemblies -Verbose
    
    if ($Static) {
        $adapter = Get-StaticAdapter
        $cacheTableName = "static{0}CacheTable"
        $cacheTable = $static.$($cacheTableName -f $memberType)
    } else {
        $adapter = Get-InstanceAdapter
        $cacheTableName = "instance{0}CacheTable"
        $cacheTable = $instance.$($cacheTableName -f $memberType)
    }
        
    if ($type -is [type]) {
        $cacheTable[$type]
    } else {
        write-warning "Could not find $type in cacheTable."
    }
}

<#
PS> $string = get-methodcachetable System.String Method
PS> $ipopulate.method.invoke($instance.adapter, "NonPublic,Static", $null, @([string], $string, [reflection.bindingflags]"NonPublic,Public,Instance"), $null)

PS C:\projects\powershell> $ipopulate.method.invoke($instance.adapter, "NonPublic,Static", $null, @([string], $string, [reflection.bindingflags]"NonPublic,Public,Instance"), $null)
Exception calling "Invoke" with "5" argument(s): "Unable to cast object of type 'MethodCacheEntry' to type 'System.Collections.ArrayList'."
At line:1 char:25
+ $ipopulate.method.invoke <<<< ($instance.adapter, "NonPublic,Static", $null, @([string], $string, [reflection.bindingflags]"NonPublic,Public,Instance"), $null)
    + CategoryInfo          : NotSpecified: (:) [], MethodInvocationException
    + FullyQualifiedErrorId : DotNetMethodTargetInvocation
 

________________________________________________________________________________________________________________________________________________________________________
PS C:\projects\powershell> $error[0].exception.tostring()
System.Management.Automation.MethodInvocationException: Exception calling "Invoke" with "5" argument(s): "Unable to cast object of type 'MethodCacheEntry' to type 'System.
Collections.ArrayList'." ---> System.InvalidCastException: Unable to cast object of type 'MethodCacheEntry' to type 'System.Collections.ArrayList'.
   at System.Management.Automation.DotNetAdapter.PopulateMethodReflectionTable(Type type, MethodInfo[] methods, CacheTable typeMethods)
   at System.Management.Automation.DotNetAdapter.PopulateMethodReflectionTable(Type type, CacheTable typeMethods, BindingFlags bindingFlags)
   --- End of inner exception stack trace ---
   at System.Management.Automation.DotNetAdapter.AuxiliaryMethodInvoke(Object target, Object[] arguments, MethodInformation methodInformation, Object[] originalArguments)
   at System.Management.Automation.DotNetAdapter.MethodInvokeDotNet(String methodName, Object target, MethodInformation[] methodInformation, Object[] arguments)
   at System.Management.Automation.Adapter.BaseMethodInvoke(PSMethod method, Object[] arguments)
   at System.Management.Automation.ParserOps.CallMethod(Token token, Object target, String methodName, Object[] paramArray, Boolean callStatic, Object valueToSet)
   at System.Management.Automation.MethodCallNode.InvokeMethod(Object target, Object[] arguments, Object value)
   at System.Management.Automation.MethodCallNode.Execute(Array input, Pipe outputPipe, ExecutionContext context)
   at System.Management.Automation.ParseTreeNode.Execute(Array input, Pipe outputPipe, ArrayList& resultList, ExecutionContext context)
   at System.Management.Automation.StatementListNode.ExecuteStatement(ParseTreeNode statement, Array input, Pipe outputPipe, ArrayList& resultList, ExecutionContext contex
t)
#>

function Enable-ObjectPeek {
    param(
        [parameter(mandatory=$true)]
        [validatenotnull()]
        [type]$Type
    )
    
    $flags = "FlattenHierarchy,Public,NonPublic,IgnoreCase"
 
    $cacheTableType = [psobject].assembly.gettype("System.Management.Automation.CacheTable")
    $populateTableSig = [type[]]([type], $cacheTableType, [reflection.bindingflags])
    
    "Property","Method","Event" | % {
        
        $memberTypeName = $_
        write-verbose "Scanning for $_"
        
        $dotNetInstanceAdapter.gettype().getmethods("NonPublic,Static") | ? {
           $_.name -eq ("GetInstance{0}ReflectionTable" -f $memberTypeName)
        } | % {

            $cache = $_.invoke($dotNetInstanceAdapter, $type)
            write-verbose "Retrieved instance cache for $membertypename"
            
            #System.Reflection.MethodInfo GetMethod(string name, System.Reflection.BindingFlags bindingAttr,
            # System.Reflection.Binder binder, type[] types, System.Reflection.ParameterModifier[] modifiers)

            $populate = $dotNetInstanceAdapter.gettype().getmethod($("Populate{0}ReflectionTable" -f $memberTypeName), "NonPublic,Static", $null, $populateTableSig, @())
            
            write-verbose "Populating $type instance ${memberTypeName}: $_"
            
            # (System.Object obj, System.Reflection.BindingFlags invokeAttr, System.Reflection.Binder binder, System.Object[] parameters, System.Globalization.CultureInfo culture)
            
            $parameters = @([type]$type, $($cache -as $cacheTableType), $(($flags + ",Instance") -as $binding))
            $host.EnterNestedPrompt()
            
            write-verbose "Invoking $populate"
            $populate.invoke($dotNetInstanceAdapter, "NonPublic,Static", $null, $parameters, $null)
        }
        
        $dotNetStaticAdapter.gettype().getmethods("NonPublic,Static") | ? {
            $_.name -eq ("GetStatic{0}ReflectionTable" -f $memberTypeName)
        } | % {
            $cache = $_.invoke($dotNetStaticAdapter, $type)
            $memberTypeName
        }
    }
}

function Disable-ObjectPeek {
    $flags =  "FlattenHierarchy,Public,Static,IgnoreCase"
}

#  | format-table -group name -auto

new-alias peek enable-objectpeek -force
new-alias unpeek disable-objectpeek -force


#enable-objectpeek $([string]) -verbose