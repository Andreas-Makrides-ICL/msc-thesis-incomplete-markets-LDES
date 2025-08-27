# MSc Thesis: Incomplete Markets in Risk and Storage Duration in Future Markets

This repository contains the work for my MSc thesis at Imperial College London. 

## 📘 Summary

The project investigates how incomplete markets and risk aversion impact investment in long-duration energy storage (LDES).

## 🔍 Project Overview

Inspired by prior research on underinvestment in resilience, this work investigates inefficiencies caused by incomplete risk trading. Models simulate both fully complete and fully incomplete market scenarios using the GB greenfield test system.

## 📁 Project Structure

- `data/`: Raw and processed weather and system input data.
- `analysis/`: Scripts for data selection, cleaning, and preprocessing.
- `models/`: Julia equilibrium models for both complete and incomplete markets.
- `plots/`: Scripts for plots, tables and post-processing analysis.

## 🛠 Tools Used

- **Julia** – for capacity expansion modeling (Complete Markets Case: central planner & Fully Incomplete Markets Case: ADMM)
- **Python** – for data, preprocessing and post-processing analysis.
**Notes**:
- All Python scripts were run through the Spyder environment and VS Code, while Julia scripts were run only in VS Code.
- Before running each script, make sure the required libraries are installed.
Python:
- For Spyder (if installed via Anaconda), install libraries from the Anaconda Prompt:

    pip install <library_name>
    or
    conda install <library_name>

- For VS Code, install libraries using the integrated terminal (PowerShell, CMD, or bash depending on your system):

    pip install <library_name>

Julia (in VS Code):
- You can install Julia packages directly in your script using:

    import Pkg
    Pkg.add("library_name")

## 🔒 Repo Access

This is a public repository. Collaborators will be manually added.

## 📝 License

MIT License – see the `LICENSE` file for details.
