using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using k8s;
using k8s.Models;
using Microsoft.AspNetCore.JsonPatch;
using Microsoft.Rest;
using Newtonsoft.Json;

namespace namespacemigrator
{
    class Program
    {
        static void Main(string[] args)
        {
            var kClient = new Kubernetes(KubernetesClientConfiguration.BuildDefaultConfig());

            var namespacesTask = kClient.ListNamespaceWithHttpMessagesAsync();
            namespacesTask.Wait();
            AssertErrors(namespacesTask.Result);

            var namespaces = namespacesTask.Result.Body.Items;
            var iamAmazonawsComPermitted = "iam.amazonaws.com/permitted";
            var namespacesWithData = namespaces
                .Where(n => n.Metadata.Labels != null)
                .Where(n => n.Metadata.Annotations != null);

            var grossList = namespacesWithData
                .Where(n => n.Metadata.Labels.All(l => l.Key != "legacy"))
                .Where(n => n.Metadata.Annotations.Any(a => a.Key == iamAmazonawsComPermitted && a.Value.EndsWith("/*")))
                .ToList();

            grossList.ForEach(g=>Console.WriteLine($"{g.Metadata.Name} - Annotation: {g.Metadata.Annotations.FirstOrDefault(a=>a.Key==iamAmazonawsComPermitted).Value}"));

            
            foreach (var v1Namespace in grossList)
            {
                var meta = v1Namespace.Metadata;
                var oldValue = meta.Annotations.Single(a => a.Key == iamAmazonawsComPermitted).Value;
                meta.Annotations[iamAmazonawsComPermitted] = oldValue.Replace("/*", "/.*");

                var patch = new JsonPatchDocument<V1Namespace>();
                patch.Replace(p => p.Metadata, meta);
                // Do patch
                kClient.PatchNamespaceWithHttpMessagesAsync(new V1Patch(patch), v1Namespace.Metadata.Name);
                Console.WriteLine($"Patched {v1Namespace.Metadata.Name}");
            }

            Console.ReadKey();
        }
        
        static void AssertErrors(HttpOperationResponse result)
        {
            result.Response.EnsureSuccessStatusCode();

            if (result.Response.StatusCode != HttpStatusCode.OK)
                throw new Exception($"Not statusCode OK. Was {result.Response.StatusCode}");
        }
    }
}
