using UnityEngine;

namespace DeliveryDisaster.Utils
{
    /// <summary>
    /// Generic persistent MonoBehaviour singleton base used by manager classes
    /// (GameManager, EconomyManager, AudioManager, etc.) so every manager gets
    /// consistent lifecycle behaviour without duplicating boilerplate.
    /// </summary>
    public abstract class Singleton<T> : MonoBehaviour where T : MonoBehaviour
    {
        private static T instance;
        private static bool isShuttingDown;

        public static T Instance
        {
            get
            {
                if (isShuttingDown)
                {
                    return null;
                }

                if (instance == null)
                {
                    instance = FindObjectOfType<T>();

                    if (instance == null)
                    {
                        var go = new GameObject(typeof(T).Name);
                        instance = go.AddComponent<T>();
                    }
                }

                return instance;
            }
        }

        protected virtual bool Persistent => true;

        protected virtual void Awake()
        {
            if (instance != null && instance != this as T)
            {
                Destroy(gameObject);
                return;
            }

            instance = this as T;

            if (Persistent)
            {
                transform.SetParent(null);
                DontDestroyOnLoad(gameObject);
            }
        }

        protected virtual void OnApplicationQuit()
        {
            isShuttingDown = true;
        }

        protected virtual void OnDestroy()
        {
            if (instance != this as T) return;

            instance = null;

            // Only latch isShuttingDown for persistent (DontDestroyOnLoad) singletons, whose
            // OnDestroy realistically only fires at application quit. A non-persistent
            // (scene-scoped) singleton is destroyed on every normal scene unload too - latching
            // here would permanently stop it from ever re-registering on the next scene load.
            if (Persistent)
            {
                isShuttingDown = true;
            }
        }
    }
}
