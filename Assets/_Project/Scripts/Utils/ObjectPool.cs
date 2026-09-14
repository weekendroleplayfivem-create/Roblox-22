using System.Collections.Generic;
using UnityEngine;

namespace DeliveryDisaster.Utils
{
    /// <summary>
    /// Minimal generic component pool. Used by disasters and traffic to avoid
    /// Instantiate/Destroy churn for short-lived VFX/debris/NPC objects.
    /// </summary>
    public class ObjectPool<T> where T : Component
    {
        private readonly T prefab;
        private readonly Transform parent;
        private readonly Stack<T> pool = new Stack<T>();

        public ObjectPool(T prefab, int prewarm = 0, Transform parent = null)
        {
            this.prefab = prefab;
            this.parent = parent;

            for (int i = 0; i < prewarm; i++)
            {
                Release(CreateNew());
            }
        }

        private T CreateNew()
        {
            var instance = Object.Instantiate(prefab, parent);
            instance.gameObject.SetActive(false);
            return instance;
        }

        public T Get(Vector3 position, Quaternion rotation)
        {
            T instance = pool.Count > 0 ? pool.Pop() : CreateNew();
            instance.transform.SetPositionAndRotation(position, rotation);
            instance.gameObject.SetActive(true);
            return instance;
        }

        public void Release(T instance)
        {
            if (instance == null) return;
            instance.gameObject.SetActive(false);
            pool.Push(instance);
        }
    }
}
