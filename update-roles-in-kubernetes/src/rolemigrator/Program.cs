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

namespace rolemigrator
{
    class Program
    {
        static void Main(string[] args)
        {
            var kClient = new Kubernetes(KubernetesClientConfiguration.BuildDefaultConfig());

            var namespacesTask = kClient.ListNamespaceWithHttpMessagesAsync();
            namespacesTask.Wait();
            AssertErrors(namespacesTask.Result);

            var namespaces = namespacesTask.Result.Body;

            var namespaceSet = namespaces.Items.Select(e => new
                {NamespaceName = e.Metadata.Name, Role = GetRole(kClient, e.Metadata.Name)}).Where(e=>e.Role!=null).ToList();

            
            // Just to assert existing Policies
            var thoseWithProperRights = namespaceSet.Where(n =>
                n.Role.Rules.Any(r => r.ApiGroups.Any(a => a == "rbac.authorization.k8s.io"))).ToList();
            
            // List of Roles with missing policy
            var thoseWithoutProperRights = namespaceSet.Where(n =>
                n.Role.Rules.All(r => r.ApiGroups.All(a => a != "rbac.authorization.k8s.io"))).ToList();
            
            
            foreach (var thoseWithoutProperRight in thoseWithoutProperRights)
            {
                var policy = new V1PolicyRule
                {
                    ApiGroups = new List<string>
                    {
                        "rbac.authorization.k8s.io"
                    },
                    Resources = new List<string>
                    {
                        "rolebindings",
                        "roles"
                    },
                    Verbs = new List<string>
                    {
                        "*"
                    }
                };
                var patch = new JsonPatchDocument<V1Role>();
                patch.Add(p => p.Rules, policy);
                try
                {
                    var body = new V1Patch(patch);
                    var patchTask = kClient.PatchNamespacedRoleWithHttpMessagesAsync(body,thoseWithoutProperRight.Role.Metadata.Name, thoseWithoutProperRight.NamespaceName);
                    patchTask.Wait();
                    Console.WriteLine($"Updated Policy on {thoseWithoutProperRight.Role.Metadata.Name}");
                }
                catch (Exception e)
                {
                
                    Console.WriteLine(e);
                    throw;
                }
            }
            
            
            
            Console.ReadKey();
            
            
            
            
        }


        static V1Role GetRole(Kubernetes client, string namespaceName)
        {

            var rolesTask = client.ListNamespacedRoleWithHttpMessagesAsync(namespaceName);
            rolesTask.Wait();
            AssertErrors(rolesTask.Result);
            var fullAccessRole =
                rolesTask.Result.Body.Items.SingleOrDefault(i => i.Metadata.Name.EndsWith("-fullaccess"));

            return fullAccessRole;
        }

    static void AssertErrors(HttpOperationResponse result)
        {

            result.Response.EnsureSuccessStatusCode();

            if (result.Response.StatusCode != HttpStatusCode.OK)
                throw new Exception($"Not statusCode OK. Was {result.Response.StatusCode}");
            
        }
        


    }
}
