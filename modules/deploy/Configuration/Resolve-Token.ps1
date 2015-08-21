<#
The MIT License (MIT)

Copyright (c) 2015 Objectivity Bespoke Software Specialists

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

function Resolve-Token {
     <#
    .SYNOPSIS
    Substitutes occurences of '${tokenName}' in given token (defined by Name and Value).

    .DESCRIPTION
    It searches $Value for occurrences of '${tokenName}' and replaces them with a value from $ResolvedTokens.
    It is done in a loop in case '${tokenName}' resolves to '${anotherTokenName}' (which again needs resolving). No more than 20 such nestings are allowed.

    .PARAMETER Name
    Name of token which value will be parsed.

    .PARAMETER Value
    Value the token that will be parsed and substituted.

    .PARAMETER ResolvedTokens
    A hashtable containing resolved tokens, which will be used for substitutions in $Value.

    .PARAMETER Category
    Name of category the parsed token belongs to.

    .PARAMETER ValidateExistence
    If true and token doesn't exist in ResolvedTokens, an exception will be thrown.

    .PARAMETER TokenRegex
    Regex used to find tokens in the file. Whole TokenRegex should match whole string to replace, first capture group should match name of the token.

    .EXAMPLE
    $newValue = Resolve-Token -Name $tokenKey -Value $tokenValue -ResolvedTokens $resolvedTokens -Category $category

    #>  
    [CmdletBinding()]
    [OutputType([string])]
    param(

        [Parameter(Mandatory=$true)]
        [string] 
        $Name, 

        [Parameter(Mandatory=$false)]
        [object] 
        $Value, 
        
        [Parameter(Mandatory=$true)]
        [hashtable] 
        $ResolvedTokens,

        [Parameter(Mandatory=$false)]
        [string] 
        $Category,

        [Parameter(Mandatory=$false)]
        [switch] 
        $ValidateExistence = $true,

        [Parameter(Mandatory=$false)]
        [string] 
        $TokenRegex = '\$\{(\w+)\}'
    )
    if (!$Value -or $Value.GetType().FullName -ne "System.String") {
        return $Value
    }
    $i = 0
    do {
        $substituted = $false    
        if ($Value -match $TokenRegex) {
            $strToReplace = $matches[0] -replace '\$', '\$'
            $key = $matches[1]
            # search in all categories, but first in '$Category'

            $allCategories = @()
            if ($Category) {
                $allCategories += $Category
            }
            # SuppressScriptCop - adding small arrays is ok
            $ResolvedTokens.Keys | Where-Object { $_ -ne $Category } | Foreach-Object { $allCategories += $_ }
            foreach ($cat in $allCategories) {               
                if ($ResolvedTokens[$cat].ContainsKey($key)) {
                    $newValue = $ResolvedTokens[$cat][$Key]
                    # if newValue is scriptblock, it means this is first pass of Resolve-tokens - we need to ignore it (will be resolved in 3rd pass)
                    if ($newValue -is [scriptblock]) {
                        break
                    }
                    $Value = $Value -replace $strToReplace, $newValue
                    $substituted = $true
                    break
                }
            }
            if (!$substituted -and $ValidateExistence) {
                throw "Cannot resolve variable '$key' in token '$Name' = '$Value'. Please ensure token named '$key' is available in your configuration."
            }
        }
        $i++
    } while ($substituted -and $i -lt 20)
    if ($i -eq 20) {
        throw 'Too many nested tokens (more than 20 loops). Ensure you don''t have circular reference in your tokens (e.g. a=${b}, b=${a})'
    }
    return $Value
}

