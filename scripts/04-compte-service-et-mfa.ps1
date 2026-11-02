# A. Compte de service au moindre privilège (rôle temporaire).
# B. Refus de suppression sans MFA, évalué au simulateur.
# À exécuter depuis la racine du dépôt : les politiques sont lues dans policies/.

$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "eu-west-3"
$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$ACC = aws sts get-caller-identity --query Account --output text
$BC = "iam-ci-sensor-1"

# --- A. Compte de service ---
aws s3 mb s3://$BC
aws iam create-user --user-name ci-runner | Out-Null
$k = aws iam create-access-key --user-name ci-runner --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
$AK, $SK = $k -split "\s+"
aws configure set aws_access_key_id $AK --profile ci-runner
aws configure set aws_secret_access_key $SK --profile ci-runner
aws configure set region eu-west-3 --profile ci-runner

aws iam create-role --role-name role-ci-deploy --assume-role-policy-document file://policies/confiance-role-ci.json | Out-Null
aws iam put-role-policy --role-name role-ci-deploy --policy-name deploy --policy-document file://policies/deploiement-releases.json
aws iam put-user-policy --user-name ci-runner --policy-name assume-ci --policy-document file://policies/assume-role-ci.json

"v1" | aws s3 cp - s3://$BC/releases/v1.txt --profile ci-runner   # refus attendu : aucun droit direct

$c = (aws sts assume-role --role-arn "arn:aws:iam::${ACC}:role/role-ci-deploy" --role-session-name session-ci --profile ci-runner | ConvertFrom-Json).Credentials
aws configure set aws_access_key_id $c.AccessKeyId --profile ci-role
aws configure set aws_secret_access_key $c.SecretAccessKey --profile ci-role
aws configure set aws_session_token $c.SessionToken --profile ci-role
aws configure set region eu-west-3 --profile ci-role
"Expiration : $($c.Expiration)"

"v1" | aws s3 cp - s3://$BC/releases/v1.txt --profile ci-role      # autorisé
"x"  | aws s3 cp - s3://$BC/autre/x.txt --profile ci-role           # refus attendu
aws s3 ls s3://$BC --profile ci-role                                # refus attendu
aws s3 ls s3://$BC --recursive                                      # contrôle en administrateur

# --- B. MFA ---
aws iam create-user --user-name admin-ops | Out-Null
aws iam create-group --group-name admins-ops | Out-Null
aws iam add-user-to-group --user-name admin-ops --group-name admins-ops
aws iam attach-group-policy --group-name admins-ops --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
aws iam put-group-policy --group-name admins-ops --policy-name exiger-mfa --policy-document file://policies/exiger-mfa-suppression.json

function sim_mfa($mfa, $action, $type = "boolean") {
  aws iam simulate-principal-policy --policy-source-arn "arn:aws:iam::${ACC}:user/admin-ops" --action-names $action --resource-arns "arn:aws:s3:::$BC/releases/v1.txt" --context-entries "ContextKeyName=aws:MultiFactorAuthPresent,ContextKeyValues=${mfa},ContextKeyType=${type}" --query "EvaluationResults[].EvalDecision" --output text
}
sim_mfa false s3:DeleteObject
sim_mfa true  s3:DeleteObject   # allowed attendu sur AWS ; le simulateur de l'émulateur ignore la clé MFA
sim_mfa false s3:GetObject
