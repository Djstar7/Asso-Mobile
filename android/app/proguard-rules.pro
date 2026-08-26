# 1. Supprimer les avertissements pour les composants Stripe non utilisés (Push Provisioning)
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider

# 2. Préserver les classes principales de Stripe pour éviter la corruption du build
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**

# 3. Conserver les annotations et attributs nécessaires à la sérialisation Stripe / Gson
-keepattributes Signature, *Annotation*, SourceFile, LineNumberTable