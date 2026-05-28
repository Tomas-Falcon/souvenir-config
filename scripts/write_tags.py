import uuid
import requests

# Configuration
DOMAIN = "tomas-falcon.github.io/souvenir-config"
BATCH_ID = "MADRID-2024-001"
SUPABASE_URL = "https://apknmsbrbmtjidmrngnk.supabase.co"
SUPABASE_KEY = "sb_publishable_1ZymSc3eQia5scNC2mmWXw_ke1Wlppb"

def register_tag(tag_uuid):
    """Registers a new unassigned tag in the Supabase database."""
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal"
    }
    data = {
        "uuid": tag_uuid,
        "status": "unassigned",
        "batch_id": BATCH_ID
    }
    response = requests.post(f"{SUPABASE_URL}/rest/v1/tags", json=data, headers=headers)
    if response.status_code == 201:
        print(f"Successfully registered tag {tag_uuid} in DB.")
    else:
        print(f"Failed to register tag {tag_uuid}: {response.text}")

def generate_ndef_url(tag_uuid):
    """Generates the URL that will be written to the NFC tag."""
    return f"https://{DOMAIN}/m/{tag_uuid}"

def main():
    print("NFC Souvenirs - Tag Fabrication Script")
    # In a real scenario, this would loop and wait for an NFC reader event
    # For now, we simulate creating and registering 5 tags
    for i in range(5):
        new_uuid = str(uuid.uuid4())
        url = generate_ndef_url(new_uuid)
        
        print(f"\n--- Tag {i+1} ---")
        print(f"Generated UUID: {new_uuid}")
        print(f"NDEF URL: {url}")
        
        register_tag(new_uuid) 
        print("Action: Write this URL to NTAG215 and set Lock Bit.")

if __name__ == "__main__":
    main()
