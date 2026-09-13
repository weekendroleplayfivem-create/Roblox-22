using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Drops a line of barriers/cones across the road for the duration, narrowing or blocking the lane. Non-damaging by default - purely a routing/timing obstacle.</summary>
    public class ConstructionZoneDisaster : DisasterBase
    {
        [SerializeField] private int barrierCount = 5;
        [SerializeField] private float lineLength = 8f;

        private readonly List<GameObject> barriers = new List<GameObject>();
        private GameObject warningMarker;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cube, new Vector3(lineLength, 0.05f, 2f), new Color(1f, 0.55f, 0f, 0.5f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);

            for (int i = 0; i < barrierCount; i++)
            {
                float t = barrierCount <= 1 ? 0f : i / (float)(barrierCount - 1);
                Vector3 pos = SpawnLocation + transform.right * Mathf.Lerp(-lineLength * 0.5f, lineLength * 0.5f, t);

                var barrier = GameObject.CreatePrimitive(PrimitiveType.Cube);
                barrier.transform.position = pos + Vector3.up * 0.5f;
                barrier.transform.localScale = new Vector3(0.6f, 1f, 0.6f);

                var renderer = barrier.GetComponent<Renderer>();
                var mat = new Material(Shader.Find("Standard"));
                mat.color = new Color(1f, 0.6f, 0f);
                renderer.material = mat;

                var col = barrier.GetComponent<Collider>();
                col.isTrigger = false;
                barrier.AddComponent<Obstacle>(); // default contactDamage - light bump only, tune per design taste

                barriers.Add(barrier);
            }
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            foreach (var barrier in barriers)
            {
                if (barrier != null) Destroy(barrier);
            }
            barriers.Clear();
        }
    }
}
