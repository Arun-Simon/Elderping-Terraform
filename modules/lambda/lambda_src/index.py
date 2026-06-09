import json
import os
import logging
import boto3
import psycopg2
from datetime import datetime, timedelta, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REMINDERS_TOPIC_ARN        = os.environ["REMINDERS_TOPIC_ARN"]
CAREGIVER_ALERTS_TOPIC_ARN = os.environ["CAREGIVER_ALERTS_TOPIC_ARN"]
DB_SECRET_ARN              = os.environ["DB_SECRET_ARN"]
AWS_REGION                 = os.environ.get("AWS_REGION_NAME", "us-east-1")

sns = boto3.client("sns",             region_name=AWS_REGION)
sm  = boto3.client("secretsmanager",  region_name=AWS_REGION)


def get_db_credentials():
    response = sm.get_secret_value(SecretId=DB_SECRET_ARN)
    return json.loads(response["SecretString"])


def get_db_connection(creds):
    return psycopg2.connect(
        host=creds["host"], port=creds.get("port", 5432),
        dbname=creds["dbname"], user=creds["username"],
        password=creds["password"], connect_timeout=10, sslmode="require",
    )


def fetch_upcoming_reminders(conn):
    now    = datetime.now(timezone.utc)
    window = now + timedelta(minutes=10)
    with conn.cursor() as cur:
        cur.execute("""
            SELECT r.id, r.patient_id, r.medication_name, r.scheduled_time,
                   u.phone_number, u.email, c.phone_number AS caregiver_phone
            FROM reminders r
            JOIN users u ON u.id = r.patient_id
            LEFT JOIN caregiver_assignments ca ON ca.patient_id = r.patient_id
            LEFT JOIN users c ON c.id = ca.caregiver_id
            WHERE r.scheduled_time BETWEEN %s AND %s
              AND r.notified = FALSE AND r.active = TRUE
            ORDER BY r.scheduled_time ASC LIMIT 100
        """, (now, window))
        columns = [desc[0] for desc in cur.description]
        return [dict(zip(columns, row)) for row in cur.fetchall()]


def mark_reminder_notified(conn, reminder_id):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE reminders SET notified=TRUE, notified_at=NOW() WHERE id=%s",
            (reminder_id,)
        )
    conn.commit()


def publish_patient_reminder(reminder):
    message = (
        f"Medication Reminder\n"
        f"Patient ID : {reminder['patient_id']}\n"
        f"Medication : {reminder['medication_name']}\n"
        f"Due at     : {reminder['scheduled_time'].strftime('%H:%M UTC')}"
    )
    sns.publish(TopicArn=REMINDERS_TOPIC_ARN, Message=message,
                Subject="ElderPing - Medication Due")
    logger.info("Patient notification sent for reminder %s", reminder["id"])


def publish_caregiver_alert(reminder):
    if not reminder.get("caregiver_phone"):
        return
    message = (
        f"Caregiver Alert\n"
        f"Patient ID {reminder['patient_id']} has medication due soon.\n"
        f"Medication : {reminder['medication_name']}\n"
        f"Due at     : {reminder['scheduled_time'].strftime('%H:%M UTC')}"
    )
    sns.publish(TopicArn=CAREGIVER_ALERTS_TOPIC_ARN, Message=message,
                Subject="ElderPing - Patient Medication Alert")


def handler(event, context):
    logger.info("Reminder scheduler triggered")
    creds = get_db_credentials()
    conn  = get_db_connection(creds)
    try:
        reminders = fetch_upcoming_reminders(conn)
        logger.info("Found %d upcoming reminders", len(reminders))
        for reminder in reminders:
            try:
                publish_patient_reminder(reminder)
                publish_caregiver_alert(reminder)
                mark_reminder_notified(conn, reminder["id"])
            except Exception as exc:
                logger.error("Failed to process reminder %s: %s", reminder["id"], exc)
    finally:
        conn.close()
    return {"statusCode": 200, "body": json.dumps({"processed": len(reminders)})}