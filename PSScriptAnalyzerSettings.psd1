@{
    Severity     = @('Error', 'Warning', 'Information')

    ExcludeRules = @(
        # We pass all params to child scripts by design (splatting pattern)
        'PSReviewUnusedParameter',

        # Write-Host is acceptable for user-facing deployment scripts
        'PSAvoidUsingWriteHost',

        # False positive: triggers on parameter names like $userPassword, not hardcoded passwords
        'PSAvoidUsingPlainTextForPassword',

        # Deployment scripts receive passwords as strings from Read-Host, conversion is unavoidable
        'PSAvoidUsingConvertToSecureStringWithPlainText',

        # Functions like Get-ApplicablePolicies are clearer with plural nouns in this context
        'PSUseSingularNouns'
    )

    IncludeRules = @(
        # Security
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingUserNameAndPasswordParams',
        'PSUsePSCredentialType',

        # Code quality
        'PSUseApprovedVerbs',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidDefaultValueSwitchParameter',
        'PSAvoidGlobalVars',
        'PSAvoidUsingEmptyCatchBlock',

        # Style
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSAlignAssignmentStatement',

        # Best practices
        'PSUseOutputTypeCorrectly',
        'PSProvideCommentHelp',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingPositionalParameters'
    )

    Rules        = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }

        PSUseConsistentWhitespace  = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSProvideCommentHelp       = @{
            Enable                  = $true
            ExportedOnly            = $true
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'begin'
        }
    }
}
