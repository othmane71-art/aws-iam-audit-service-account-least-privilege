# Politique minimale pour une analyste : lire uniquement reports/2026/ du bucket de données.
# Dix tests : trois doivent réussir, sept doivent être refusés.
# À exécuter depuis la racine du dépôt. ATTENTION : les tests écrivent et suppriment ;
# Reset-Defi remet le jeu de données en état.

$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "eu-west-3"
$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$BD = "iam-defi-sensor-1"

function Reset-Defi {
  foreach ($key in "reports/2026/janvier.txt","reports/2026/fevrier.txt","reports/2025/archive.txt","rh/salaires.txt","reports/2026-brouillon.txt") {
    "contenu de $key" | aws s3 cp - s3://$BD/$key
  }
  aws s3 rm s3://$BD/reports/2026/nouveau.txt
}
function ok($nom, [scriptblock]$cmd) {
  $global:TOTAL++
  & $cmd *> $null
  if ($LASTEXITCODE -eq 0) { "PASS  $nom"; $global:SCORE++ } else { "FAIL  $nom (devrait réussir)" }
}
function ko($nom, [scriptblock]$cmd) {
  $global:TOTAL++
  & $cmd *> $null
  if ($LASTEXITCODE -ne 0) { "PASS  $nom"; $global:SCORE++ } else { "FAIL  $nom (devrait être refusé)" }
}
function Test-Defi {
  aws sts get-caller-identity --profile lea *> $null
  if ($LASTEXITCODE -ne 0) { "Profil lea inutilisable"; return }
  $global:SCORE = 0; $global:TOTAL = 0
  ok "Lister reports/2026/"                    { aws s3 ls "s3://$BD/reports/2026/" --profile lea }
  ok "Lire janvier.txt"                        { aws s3 cp "s3://$BD/reports/2026/janvier.txt" - --profile lea }
  ok "Lire fevrier.txt"                        { aws s3 cp "s3://$BD/reports/2026/fevrier.txt" - --profile lea }
  ko "Lire reports/2025/archive.txt"           { aws s3 cp "s3://$BD/reports/2025/archive.txt" - --profile lea }
  ko "Lire rh/salaires.txt"                    { aws s3 cp "s3://$BD/rh/salaires.txt" - --profile lea }
  ko "Lire reports/2026-brouillon.txt (piège)" { aws s3 cp "s3://$BD/reports/2026-brouillon.txt" - --profile lea }
  ko "Lister la racine du bucket"              { aws s3 ls "s3://$BD/" --profile lea }
  ko "Écrire reports/2026/nouveau.txt"         { "x" | aws s3 cp - "s3://$BD/reports/2026/nouveau.txt" --profile lea }
  ko "Lister les utilisateurs IAM"             { aws iam list-users --profile lea }
  ko "Supprimer janvier.txt"                   { aws s3 rm "s3://$BD/reports/2026/janvier.txt" --profile lea }
  "Score : $($global:SCORE) / $($global:TOTAL)"
}

# Jeu de données et compte de l'analyste
aws s3 mb s3://$BD
Reset-Defi
aws iam create-user --user-name lea | Out-Null
$k = aws iam create-access-key --user-name lea --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
$AK, $SK = $k -split "\s+"
aws configure set aws_access_key_id $AK --profile lea
aws configure set aws_secret_access_key $SK --profile lea
aws configure set region eu-west-3 --profile lea

Test-Defi                                  # avant politique : 7 / 10
aws iam put-user-policy --user-name lea --policy-name defi --policy-document file://policies/lecture-reports-2026.json
Reset-Defi
Test-Defi                                  # après politique : 10 / 10
