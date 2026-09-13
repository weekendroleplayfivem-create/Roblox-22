using UnityEngine;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>
    /// Closes a bridge/crossing for the duration - a full-width gate that
    /// forces a detour rather than a bump-and-continue obstacle. Set
    /// DisasterDefinition.RequiredSpawnCategory to "Bridge" and place a
    /// DisasterSpawnPoint with that category at each bridge in your level.
    /// </summary>
    public class BridgeBlockedDisaster : DisasterBase
    {
        [SerializeField] private Vector3 gateSize = new Vector3(10f, 3f, 1f);

        private GameObject warningMarker;
        private GameObject gate;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cube, new Vector3(gateSize.x, 0.05f, 3f), new Color(1f, 0.2f, 0.2f, 0.5f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);

            gate = GameObject.CreatePrimitive(PrimitiveType.Cube);
            gate.name = "BridgeBlockedGate";
            gate.transform.position = SpawnLocation + Vector3.up * (gateSize.y * 0.5f);
            gate.transform.rotation = transform.rotation;
            gate.transform.localScale = gateSize;

            var renderer = gate.GetComponent<Renderer>();
            var mat = new Material(Shader.Find("Standard"));
            mat.color = new Color(0.8f, 0.1f, 0.1f);
            renderer.material = mat;

            gate.AddComponent<Obstacle>();
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            if (gate != null) Destroy(gate);
        }
    }
}
