try:
    from rembg import new_session
    new_session("isnet-anime")
    print("Model pre-downloaded successfully")
except Exception as e:
    print(f"Model pre-download skipped: {e}")
