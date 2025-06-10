import json
import os
import boto3
import logging
from typing import Dict, Any

# 로깅 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS 클라이언트 초기화
kms = boto3.client('kms')
backup = boto3.client('backup')

def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    KMS 키 자동 복구 Lambda 핸들러
    
    Args:
        event: Lambda 이벤트 데이터
        context: Lambda 컨텍스트
        
    Returns:
        Dict[str, Any]: Lambda 응답
    """
    logger.info(f"이벤트 수신: {json.dumps(event, indent=2)}")
    
    key_id = os.environ['KMS_KEY_ID']
    backup_vault_name = os.environ['BACKUP_VAULT_NAME']
    environment = os.environ['ENVIRONMENT']
    
    try:
        # 키 상태 확인
        key_details = kms.describe_key(KeyId=key_id)
        key_state = key_details['KeyMetadata']['KeyState']
        logger.info(f"키 상태: {key_state}")
        
        if key_state in ['Disabled', 'PendingDeletion']:
            # 프로덕션 환경에서는 자동 복구 전 승인 필요
            if environment == 'prod':
                logger.info("프로덕션 환경: 수동 승인 필요")
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': '프로덕션 환경에서는 수동 승인이 필요합니다.',
                        'keyId': key_id,
                        'keyState': key_state
                    })
                }
            
            # 백업이 활성화된 경우 복구 시도
            if backup_vault_name:
                try:
                    # 최근 백업 조회
                    backups = backup.list_backup_jobs(
                        ByResourceType='KMS',
                        ByResourceId=key_id,
                        ByBackupVaultName=backup_vault_name,
                        MaxResults=1
                    )
                    
                    if backups['BackupJobs']:
                        latest_backup = backups['BackupJobs'][0]
                        
                        # 복구 작업 시작
                        restore_job = backup.start_restore_job(
                            BackupVaultName=backup_vault_name,
                            RecoveryPointArn=latest_backup['RecoveryPointArn'],
                            ResourceType='KMS'
                        )
                        
                        logger.info(f"복구 작업 시작됨: {restore_job['RestoreJobId']}")
                    else:
                        logger.warning("사용 가능한 백업을 찾을 수 없습니다.")
                except Exception as e:
                    logger.error(f"백업 복구 중 오류 발생: {str(e)}")
            
            # 키가 비활성화된 경우 다시 활성화
            if key_state == 'Disabled':
                kms.enable_key(KeyId=key_id)
                logger.info("키가 다시 활성화되었습니다.")
            
            # 키가 삭제 대기 중인 경우 삭제 취소
            if key_state == 'PendingDeletion':
                kms.cancel_key_deletion(KeyId=key_id)
                kms.enable_key(KeyId=key_id)
                logger.info("키 삭제가 취소되고 다시 활성화되었습니다.")
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': '키 복구 작업이 완료되었습니다.',
                    'keyId': key_id,
                    'originalState': key_state,
                    'action': 'recovered'
                })
            }
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': '키가 정상 상태입니다.',
                'keyId': key_id,
                'keyState': key_state
            })
        }
        
    except Exception as error:
        logger.error(f"오류 발생: {str(error)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': '키 복구 중 오류가 발생했습니다.',
                'error': str(error),
                'keyId': key_id
            })
        } 