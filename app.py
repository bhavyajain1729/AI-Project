import streamlit as st
from pathlib import Path
import shutil
import os
from dotenv import load_dotenv
import main  # uses run_pipeline()

st.set_page_config(page_title="ABL Analyzer (Groq)", layout="wide")
st.title("ABL Code Analyzer (Groq)")

load_dotenv()

uploaded_files = st.file_uploader(
    "Upload .p files", type=["p"], accept_multiple_files=True
)

model = st.selectbox(
    "Select Groq Model",
    ["llama-3.1-8b-instant", "llama-3.3-70b-versatile"]
)

run = st.button("Run Analysis")

if run:
    if not uploaded_files:
        st.warning("Please upload .p files first.")
    else:
        input_dir = Path("./input")
        if input_dir.exists():
            shutil.rmtree(input_dir)
        input_dir.mkdir(parents=True, exist_ok=True)

        for f in uploaded_files:
            (input_dir / f.name).write_bytes(f.read())

        # set model in env for this run
        os.environ["MODEL"] = model

        st.info("Running analysis... please wait")
        main.run_pipeline()
        st.success("Done! Check ./output")

        st.write("Output generated in ./output")