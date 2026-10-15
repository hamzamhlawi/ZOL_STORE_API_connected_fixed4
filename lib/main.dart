
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const ZolStoreApp());

const String apiBaseUrl = 'http://node3.serverix.cloud:3145';
const String whatsappAdminNumber = '249916537047';

const bg = Color(0xFF0B1020);
const panel = Color(0xFF151D30);
const teal = Color(0xFF20D6C7);
const gold = Color(0xFFFFC857);

class ApiProduct {
  final String code, category, title, note;
  final num? price;
  ApiProduct({required this.code, required this.category, required this.title, required this.note, required this.price});
  factory ApiProduct.fromJson(Map<String, dynamic> j) => ApiProduct(
    code: '${j['code'] ?? ''}',
    category: '${j['category'] ?? 'other'}',
    title: '${j['title'] ?? j['code'] ?? 'منتج'}',
    note: '${j['note'] ?? ''}',
    price: j['price_sdg'] is num ? j['price_sdg'] as num : (j['price'] is num ? j['price'] as num : null),
  );
  String get priceLabel => price == null ? 'السعر غير محدد' : '${price!.toStringAsFixed(price! % 1 == 0 ? 0 : 2)} ج.س';
}

class StoreOrder {
  final String id, product, pack, recipient, contact;
  final DateTime createdAt;
  String status;
  StoreOrder({required this.id, required this.product, required this.pack, required this.recipient, required this.contact, required this.createdAt, this.status='بانتظار تأكيد واتساب'});
}

class ZolStoreApp extends StatelessWidget {
  const ZolStoreApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ZOL STORE', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.dark, surface: panel),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
    home: const StoreHome(),
  );
}

class StoreHome extends StatefulWidget {
  const StoreHome({super.key});
  @override State<StoreHome> createState()=>_StoreHomeState();
}
class _StoreHomeState extends State<StoreHome> {
  List<ApiProduct> products = [];
  List<StoreOrder> orders = [];
  bool loading = true;
  String? loadError;
  int tab = 0;

  @override void initState() { super.initState(); loadProducts(); }

  Future<void> loadProducts() async {
    setState(() { loading = true; loadError = null; });
    try {
      final r = await http.get(Uri.parse('$apiBaseUrl/api/products')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception('رمز الاستجابة ${r.statusCode}');
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      final List<dynamic> raw = decoded is List ? decoded : (decoded is Map && decoded['products'] is List ? decoded['products'] as List : []);
      final parsed = raw.whereType<Map>().map((e)=>ApiProduct.fromJson(Map<String,dynamic>.from(e))).where((p)=>p.code.isNotEmpty).toList();
      if (parsed.isEmpty) throw Exception('الاستجابة لا تحتوي على منتجات مفهومة');
      if (!mounted) return;
      setState(() { products = parsed; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = 'تعذر تحميل المنتجات من السيرفر. تحقق من الاتصال ثم أعد المحاولة.'; });
    }
  }

  String categoryLabel(String c) {
    switch(c.toLowerCase()) {
      case 'tiktok': case 'tiktok_coins': return 'عملات تيك توك';
      case 'telegram_stars': case 'stars': return 'نجوم تلجرام';
      case 'telegram_premium': case 'premium': return 'تلجرام المميز';
      case 'pubg': case 'pubg_uc': return 'شدات ببجي';
      case 'freefire': case 'free_fire': case 'freefire_diamonds': return 'ماسات فري فاير';
      default: return c;
    }
  }
  IconData categoryIcon(String c) {
    final s=c.toLowerCase();
    if(s.contains('pubg')) return Icons.sports_esports_rounded;
    if(s.contains('free')) return Icons.diamond_rounded;
    if(s.contains('star')) return Icons.star_rounded;
    if(s.contains('premium')) return Icons.workspace_premium_rounded;
    if(s.contains('tiktok')) return Icons.toll_rounded;
    return Icons.shopping_bag_rounded;
  }
  Color categoryColor(String c) {
    final s=c.toLowerCase();
    if(s.contains('pubg')) return const Color(0xFFFFA34D);
    if(s.contains('free')) return const Color(0xFF46B9FF);
    if(s.contains('star')) return gold;
    if(s.contains('premium')) return const Color(0xFF8A7CFF);
    if(s.contains('tiktok')) return const Color(0xFFFF5A76);
    return teal;
  }

  Future<void> openCategory(String category) async {
    final list = products.where((p)=>p.category == category).toList();
    if(list.isEmpty) return;
    final chosen = await Navigator.push<ApiProduct>(context, MaterialPageRoute(builder: (_) => ProductPage(
      categoryTitle: categoryLabel(category), items: list,
    )));
    if(chosen == null || !mounted) return;
    await createOrder(chosen);
  }

  Future<void> createOrder(ApiProduct p) async {
    final result = await Navigator.push<Map<String,String>>(context, MaterialPageRoute(builder: (_) => OrderForm(product:p)));
    if(result == null || !mounted) return;
    final recipient = result['recipient'] ?? '';
    final contact = result['contact'] ?? '';
    final customerName = result['name'] ?? 'عميل ZOL STORE';
    String orderId = DateTime.now().millisecondsSinceEpoch.toString();
    String status = 'تم تجهيز الطلب محلياً؛ جارٍ الإرسال للسيرفر';
    try {
      final response = await http.post(Uri.parse('$apiBaseUrl/api/orders'),
        headers: {'Content-Type':'application/json; charset=utf-8'},
        body: jsonEncode({'product_code':p.code, 'customer_name':customerName, 'contact':contact, 'recipient':recipient, 'quantity':1}),
      ).timeout(const Duration(seconds:20));
      final data = response.body.isNotEmpty ? jsonDecode(utf8.decode(response.bodyBytes)) : {};
      if(response.statusCode >= 200 && response.statusCode < 300) {
        if(data is Map && data['id'] != null) orderId = '${data['id']}';
        status = 'تم إرسال الطلب للسيرفر؛ أكمل تأكيد الدفع مع الإدارة';
      } else {
        status = 'تعذر حفظ الطلب في السيرفر (${response.statusCode})؛ أرسل عبر واتساب';
      }
    } catch (_) {
      status = 'تعذر الاتصال بالسيرفر؛ أرسل تفاصيل الطلب عبر واتساب';
    }
    final order = StoreOrder(id:orderId, product:categoryLabel(p.category), pack:'${p.title} — ${p.priceLabel}', recipient:recipient, contact:contact, createdAt:DateTime.now(), status:status);
    setState(()=>orders.insert(0,order));
    await sendWhatsApp(order, p.code, customerName);
  }

  Future<void> sendWhatsApp(StoreOrder order, String code, String customerName) async {
    final msg = 'السلام عليكم، طلب جديد من ZOL STORE\nرقم الطلب: ${order.id}\nالمنتج: ${order.product}\nالباقة: ${order.pack}\nكود المنتج: $code\nاسم العميل: $customerName\nبيانات المستلم/اللاعب: ${order.recipient}\nرقم تواصل العميل: ${order.contact.isEmpty ? "لم يحدد" : order.contact}\nيرجى تأكيد السعر والدفع قبل التنفيذ.';
    final uri = Uri.parse('https://wa.me/$whatsappAdminNumber?text=${Uri.encodeComponent(msg)}');
    try { await launchUrl(uri, mode:LaunchMode.externalApplication); }
    catch (_) { if(mounted) showMsg('تعذر فتح واتساب.'); }
  }
  void showMsg(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Row(children:[Icon(Icons.bolt_rounded,color:teal,size:30),SizedBox(width:8),Text('ZOL STORE',style:TextStyle(fontWeight:FontWeight.w900,letterSpacing:1))]),
      actions:[IconButton(tooltip:'تحديث المنتجات',onPressed:loadProducts,icon:const Icon(Icons.refresh)),IconButton(tooltip:'واتساب الإدارة',onPressed:()=>launchUrl(Uri.parse('https://wa.me/$whatsappAdminNumber'),mode:LaunchMode.externalApplication),icon:const Icon(Icons.chat,color:Color(0xFF25D366))),IconButton(tooltip:'طلباتي',onPressed:()=>setState(()=>tab=1),icon:Badge(label:Text('${orders.length}'),child:const Icon(Icons.receipt_long_rounded))),const SizedBox(width:4)]),
    body:tab==0 ? _home() : _orders(),
    bottomNavigationBar:NavigationBar(backgroundColor:panel,selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.storefront_outlined),selectedIcon:Icon(Icons.storefront),label:'المتجر'),
      NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'طلباتي')]),
  );

  Widget _home() {
    final categories = <String>[];
    for(final p in products) { if(!categories.contains(p.category)) categories.add(p.category); }
    return RefreshIndicator(onRefresh:loadProducts,child:ListView(padding:const EdgeInsets.fromLTRB(16,8,16,24),children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF173B55),Color(0xFF18203B)]),borderRadius:BorderRadius.circular(24),border:Border.all(color:teal.withOpacity(.25))),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('كل خدماتك الرقمية في مكان واحد',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
        SizedBox(height:8),Text('المنتجات والأسعار تُحمّل من السيرفر مباشرة.',style:TextStyle(color:Colors.white70,height:1.5)),
        SizedBox(height:16),Row(children:[Icon(Icons.cloud_done,color:Color(0xFF25D366),size:18),SizedBox(width:6),Text('متصل بواجهة API',style:TextStyle(color:Color(0xFF25D366),fontSize:12))]) ])),
      const SizedBox(height:22),
      if(loading) const Padding(padding:EdgeInsets.all(32),child:Center(child:CircularProgressIndicator()))
      else if(loadError != null) ...[
        Text(loadError!,style:const TextStyle(color:Colors.orangeAccent)),
        const SizedBox(height:12),FilledButton.icon(onPressed:loadProducts,icon:const Icon(Icons.refresh),label:const Text('إعادة المحاولة')),
      ] else ...[
        Text('تصفح الخدمات (${products.length} منتج)',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        ...categories.map((c) {
          final list=products.where((p)=>p.category==c).toList();
          final color=categoryColor(c);
          final firstPrices=list.take(3).map((p)=>p.priceLabel).join(' • ');
          return Padding(padding:const EdgeInsets.only(bottom:12),child:InkWell(borderRadius:BorderRadius.circular(20),onTap:()=>openCategory(c),child:Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20),border:Border.all(color:Colors.white.withOpacity(.06))),child:Row(children:[
            Container(width:56,height:56,decoration:BoxDecoration(color:color.withOpacity(.14),borderRadius:BorderRadius.circular(17)),child:Icon(categoryIcon(c),color:color,size:30)),
            const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(categoryLabel(c),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:5),Text('${list.length} باقة',style:const TextStyle(color:Colors.white54,fontSize:12)),const SizedBox(height:4),Text(firstPrices,style:const TextStyle(color:gold,fontSize:11),maxLines:2,overflow:TextOverflow.ellipsis)])),
            const Icon(Icons.chevron_left_rounded,color:Colors.white54)]))));
        }),
      ],
      const SizedBox(height:8),const Text('ملاحظة: إرسال الطلب لا يعني أن الدفع أو الشحن تم تلقائياً. تأكد من الإدارة.',style:TextStyle(color:Colors.white54,fontSize:12)),
    ]));
  }

  Widget _orders(){
    if(orders.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.receipt_long_outlined,size:56,color:Colors.white30),SizedBox(height:12),Text('لا توجد طلبات حتى الآن',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),SizedBox(height:6),Text('ستظهر هنا الطلبات التي أُنشئت من هذا الجهاز.',style:TextStyle(color:Colors.white54),textAlign:TextAlign.center)])));
    return ListView.builder(padding:const EdgeInsets.all(16),itemCount:orders.length,itemBuilder:(_,i){final o=orders[i];return Card(color:panel,margin:const EdgeInsets.only(bottom:12),child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0x2236D6C7),child:Icon(Icons.receipt,color:teal)),title:Text(o.product),subtitle:Text('${o.pack}\nرقم الطلب: ${o.id}\n${o.status}',maxLines:5),isThreeLine:true,trailing:IconButton(tooltip:'إرسال واتساب مجدداً',icon:const Icon(Icons.chat,color:Color(0xFF25D366)),onPressed:()=>sendWhatsApp(o,'', 'عميل ZOL STORE'))));});
  }
}

class ProductPage extends StatefulWidget {
  final String categoryTitle;
  final List<ApiProduct> items;
  const ProductPage({super.key,required this.categoryTitle,required this.items});
  @override State<ProductPage> createState()=>_ProductPageState();
}
class _ProductPageState extends State<ProductPage>{
  int selected=0;
  @override Widget build(BuildContext context){
    final first=widget.items.first;
    return Scaffold(appBar:AppBar(title:Text(widget.categoryTitle)),body:ListView(padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:teal.withOpacity(.1),borderRadius:BorderRadius.circular(24)),child:Column(children:[const Icon(Icons.shopping_bag_rounded,color:teal,size:52),const SizedBox(height:10),Text(widget.categoryTitle,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),Text('${widget.items.length} باقة متاحة',style:const TextStyle(color:Colors.white54))])),
      const SizedBox(height:24),const Text('اختر الباقة',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:10),
      ...List.generate(widget.items.length,(i){final p=widget.items[i];return RadioListTile<int>(value:i,groupValue:selected,onChanged:(v)=>setState(()=>selected=v??0),activeColor:teal,tileColor:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),title:Text(p.title),subtitle:Text('${p.priceLabel}${p.note.isNotEmpty ? "\n${p.note}" : ""}',style:const TextStyle(color:gold)),contentPadding:const EdgeInsets.symmetric(horizontal:12));}),
      const SizedBox(height:20),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:teal,foregroundColor:bg,padding:const EdgeInsets.symmetric(vertical:16)),onPressed:()=>Navigator.pop(context,widget.items[selected]),icon:const Icon(Icons.arrow_forward),label:const Text('متابعة الطلب',style:TextStyle(fontWeight:FontWeight.bold))),
    ]));
  }
}

class OrderForm extends StatefulWidget {
  final ApiProduct product;
  const OrderForm({super.key,required this.product});
  @override State<OrderForm> createState()=>_OrderFormState();
}
class _OrderFormState extends State<OrderForm>{
  final name=TextEditingController(),recipient=TextEditingController(),contact=TextEditingController();
  @override void dispose(){name.dispose();recipient.dispose();contact.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('بيانات الطلب')),body:ListView(padding:const EdgeInsets.all(18),children:[
    Text(widget.product.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
    const SizedBox(height:6),Text(widget.product.priceLabel,style:const TextStyle(color:gold,fontSize:16)),
    const SizedBox(height:18),TextField(controller:name,decoration:const InputDecoration(labelText:'اسم العميل',prefixIcon:Icon(Icons.person_outline))),
    const SizedBox(height:12),TextField(controller:recipient,decoration:const InputDecoration(labelText:'معرّف اللاعب أو المستلم',hintText:'لا تدخل كلمة مرور حسابك',prefixIcon:Icon(Icons.account_circle_outlined))),
    const SizedBox(height:12),TextField(controller:contact,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'رقم التواصل / واتساب (اختياري)',prefixIcon:Icon(Icons.chat_outlined))),
    const SizedBox(height:22),FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:teal,foregroundColor:bg,padding:const EdgeInsets.symmetric(vertical:16)),onPressed:(){
      if(recipient.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل معرّف المستلم أولاً')));return;}
      Navigator.pop(context,{'name':name.text.trim().isEmpty?'عميل ZOL STORE':name.text.trim(),'recipient':recipient.text.trim(),'contact':contact.text.trim()});
    },icon:const Icon(Icons.send),label:const Text('إنشاء الطلب وإرساله',style:TextStyle(fontWeight:FontWeight.bold))),
    const SizedBox(height:12),const Text('لا تدخل كلمة مرور حسابك. تأكيد الدفع والشحن يتم من الإدارة.',style:TextStyle(color:Colors.white54,fontSize:12),textAlign:TextAlign.center)
  ]));
}