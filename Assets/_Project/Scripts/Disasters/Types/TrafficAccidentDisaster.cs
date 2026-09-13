using System.Collections.Generic;
using UnityEngine;
using DeliveryDisaster.World;

namespace DeliveryDisaster.Disasters.Types
{
    /// <summary>Spawns a pile-up of wrecked vehicle obstacles blocking part of the road for the disaster's duration, forcing traffic and the player to route around.</summary>
    public class TrafficAccidentDisaster : DisasterBase
    {
        [SerializeField] private int wreckCount = 2;
        [SerializeField] private float spreadRadius = 3f;

        private readonly List<GameObject> wrecks = new List<GameObject>();
        private GameObject warningMarker;

        protected override void OnTelegraph()
        {
            warningMarker = SpawnPlaceholderVisual(PrimitiveType.Cube, new Vector3(4f, 0.05f, 4f), new Color(1f, 0.8f, 0f, 0.5f));
        }

        protected override void OnActivate()
        {
            if (warningMarker != null) Destroy(warningMarker);

            for (int i = 0; i < wreckCount; i++)
            {
                Vector2 offset = Random.insideUnitCircle * spreadRadius;
                Vector3 pos = SpawnLocation + new Vector3(offset.x, 0.5f, offset.y);

                var wreck = GameObject.CreatePrimitive(PrimitiveType.Cube);
                wreck.transform.position = pos;
                wreck.transform.rotation = Random.rotation;
                wreck.transform.localScale = new Vector3(2f, 1f, 4f);

                var renderer = wreck.GetComponent<Renderer>();
                var mat = new Material(Shader.Find("Standard"));
                mat.color = new Color(0.3f, 0.05f, 0.05f);
                renderer.material = mat;

                var rb = wreck.AddComponent<Rigidbody>();
                rb.mass = 200f;
                wreck.AddComponent<Obstacle>();

                wrecks.Add(wreck);
            }
        }

        protected override void OnCleanup()
        {
            if (warningMarker != null) Destroy(warningMarker);
            foreach (var wreck in wrecks)
            {
                if (wreck != null) Destroy(wreck);
            }
            wrecks.Clear();
        }
    }
}
