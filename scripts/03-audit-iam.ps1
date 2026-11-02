# Audit IAM : six indicateurs de configuration excessive.
# Les politiques sont lues avec des expressions régulières : le script ne voit que ce qu'on lui a appris à chercher.

$users = (aws iam list-users --query 'Users[].UserName' --output text) -split "\s+" | Where-Object { $_ }

"== 1. Utilisateurs administrateurs =="
foreach ($u in $users) {
  $p = aws iam list-attached-user-policies --user-name $u --query "AttachedPolicies[].PolicyName" --output text
  if ($p -match "AdministratorAccess") { "ALERTE : $u a AdministratorAccess" }
}

"== 2. Utilisateurs sans MFA =="
foreach ($u in $users) {
  $n = aws iam list-mfa-devices --user-name $u --query "length(MFADevices)" --output text
  if ($n -eq "0") { "ALERTE : $u sans MFA" }
}

"== 3. Utilisateurs avec plusieurs clés d'accès =="
foreach ($u in $users) {
  $n = aws iam list-access-keys --user-name $u --query "length(AccessKeyMetadata)" --output text
  if ([int]$n -gt 1) { "ALERTE : $u a $n clés d'accès" }
}

"== 4. Utilisateurs hors de tout groupe =="
foreach ($u in $users) {
  $n = aws iam list-groups-for-user --user-name $u --query "length(Groups)" --output text
  if ($n -eq "0") { "INFO : $u n'appartient à aucun groupe" }
}

"== 5. Rôles à confiance ouverte =="
foreach ($r in ((aws iam list-roles --query "Roles[].RoleName" --output text) -split "\s+" | Where-Object { $_ })) {
  $doc = (aws iam get-role --role-name $r --query "Role.AssumeRolePolicyDocument" --output json) -join ""
  if ($doc -match '"AWS":\s*"\*"|"Principal":\s*"\*"') { "ALERTE : le rôle $r est assumable par n'importe qui" }
}

"== 6. Politiques locales avec Action * =="
foreach ($arn in ((aws iam list-policies --scope Local --query "Policies[].Arn" --output text) -split "\s+" | Where-Object { $_ })) {
  $v = aws iam get-policy --policy-arn $arn --query "Policy.DefaultVersionId" --output text
  $doc = (aws iam get-policy-version --policy-arn $arn --version-id $v --query "PolicyVersion.Document" --output json) -join ""
  if ($doc -match '"Action":\s*"\*"') { "ALERTE : $arn contient Action *" }
}
