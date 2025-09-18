
import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial.distance import pdist
import pandas as pd

import numpy as np
import matplotlib.pyplot as plt
from scipy.spatial.distance import pdist
import pandas as pd
import multiprocessing
import os

idx = pd.IndexSlice


def hierarchical_chronological_clustering(data, n_reduced):
    """
    Perform hierarchical clustering on univariate or multivariate data based on chronological adjacency and Ward's method.
    
    Parameters:
    - data: A numpy array where each row corresponds to a time period (e.g., hour), and columns represent attributes.
    - n_reduced: The desired reduced number of clusters (N').
    
    Returns:
    - cluster_centroids: A numpy array of centroids of the resulting clusters.
    - cluster_weights: Number of hours in each cluster (used as weights).
    """
    # Step 1: Initialize each time period as its own cluster
    n = data.shape[0]  # Number of time periods
    clusters = [[i] for i in range(n)]  # Initially, each time period is a separate cluster
    
    # Step 2: Function to compute centroids for univariate or multivariate data
    def compute_centroid(cluster):
        return np.mean(data[cluster], axis=0)

    # Step 3: Compute dissimilarity between adjacent clusters for univariate or multivariate data
    def compute_dissimilarity(cluster1, cluster2):
        centroid1 = compute_centroid(cluster1)
        centroid2 = compute_centroid(cluster2)
        # Using Ward's method: D(I, J) = 2|I||J| / (|I| + |J|) * ||centroid1 - centroid2||^2
        size1, size2 = len(cluster1), len(cluster2)
        dissimilarity = 2 * size1 * size2 / (size1 + size2) * (pdist(np.vstack([centroid1, centroid2])) ** 2)
        return dissimilarity
    
    # Step 4: Iterate until the desired number of clusters is reached
    while len(clusters) > n_reduced:
        print(f"Number of clusters: {len(clusters)}")
        if len(clusters) % 1000 == 0:
            print(f"Number of clusters: {len(clusters)}")
        # Find the pair of adjacent clusters with the smallest dissimilarity
        min_dissimilarity = float('inf')
        merge_idx = (-1, -1)
        for i in range(len(clusters) - 1):
            dissimilarity = compute_dissimilarity(clusters[i], clusters[i + 1])
            if dissimilarity < min_dissimilarity:
                min_dissimilarity = dissimilarity
                merge_idx = (i, i + 1)
        
        # Merge the closest adjacent clusters
        i, j = merge_idx
        clusters[i] = clusters[i] + clusters[j]  # Merge cluster j into cluster i
        del clusters[j]  # Remove cluster j

    # Step 5: Calculate centroids and weights of the final clusters
    cluster_centroids = np.array([compute_centroid(cluster) for cluster in clusters])
    cluster_weights = np.array([len(cluster) for cluster in clusters])

    return cluster_centroids, cluster_weights

def process_scenarios(scenarios, n_reduced=672):
    """
    Process the given scenarios to perform hierarchical chronological clustering and save the results to CSV files.

    Parameters:
    - scenarios: List of scenario identifiers to process.
    - n_reduced: The desired reduced number of clusters (N'). Default is 720.
    """
    # Load data
    data_load = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_CF_cluster_fix\clustering_new\sampled_normalized_data_40.csv")
    data_cf = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_CF_cluster_fix\clustering_new\data_VRE_final.csv")
    data_full = pd.concat([data_load.set_index(["Y", "T"]), data_cf.set_index(["Y", "T"])], axis=1)

    clustered_data = {}

    for s in scenarios:
        print("Running scenario ", s)
        data = data_full.loc[idx[s, :], :].reset_index(drop=True).values
        cluster_centroids, cluster_weights = hierarchical_chronological_clustering(data, n_reduced)
        clustered_data[s] = {"cluster": cluster_centroids, "weights": cluster_weights}

    data_load_clustered = pd.DataFrame(index=pd.MultiIndex.from_product([scenarios, range(1, n_reduced + 1)], names=['Y', 'T']), columns=data_load.set_index(["Y", "T"]).columns)
    data_cf_clustered = pd.DataFrame(index=pd.MultiIndex.from_product([scenarios, range(1, n_reduced + 1)], names=['Y', 'T']), columns=data_cf.set_index(["Y", "T"]).columns)
    data_clustered_weights = pd.DataFrame(index=pd.MultiIndex.from_product([scenarios, range(1, n_reduced + 1)], names=['Y', 'T']), columns=["Weights"])

    for s in scenarios:
        data_load_clustered.loc[s, :] = clustered_data[s]["cluster"][:, :(len(data_load.columns) - 2)]
        data_cf_clustered.loc[s, :] = clustered_data[s]["cluster"][:, (len(data_load.columns) - 2):]
        data_clustered_weights.loc[s, :] = clustered_data[s]["weights"]

    # Create a folder to store the clustered data
    folder = r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_CF_cluster_fix\clustering_new\clustered_data"
    if not os.path.exists(folder):
        os.makedirs(folder)

    # Export clustered data to the folder
    data_load_clustered.to_csv(os.path.join(folder, 'load_profile_clustered_%d_%s_.csv' % (n_reduced, scenarios[0])))
    data_cf_clustered.to_csv(os.path.join(folder, 'capacity_factors_gen_clustered_%d_%s_.csv' % (n_reduced, scenarios[0])))
    data_clustered_weights.to_csv(os.path.join(folder, 'weights_clustered_%d_%s_.csv' % (n_reduced, scenarios[0])))

def run_scenario(scenario):
    scenarios = [scenario]
    process_scenarios(scenarios)

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    with multiprocessing.Pool(30) as pool:
        pool.map(run_scenario, range(1, 31))
