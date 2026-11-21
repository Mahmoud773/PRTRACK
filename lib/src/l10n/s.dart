class S {
  const S(this.ar);
  final bool ar;

  String get signIn => ar ? 'دخول' : 'Sign in';
  String get username => ar ? 'اسم المستخدم' : 'Username';
  String get password => ar ? 'كلمة المرور' : 'Password';
  String get language => ar ? 'English' : 'العربية';
  String get requests => ar ? 'الطلبات' : 'Requests';
  String get notifications => ar ? 'الإشعارات' : 'Notifications';
  String get settings => ar ? 'الإعدادات' : 'Settings';
  String get help => ar ? 'مساعدة' : 'Help';
  String get dashboard => ar ? 'اللوحة' : 'Dashboard';
  String get users => ar ? 'المستخدمون' : 'Users';
  String get fresh => ar ? 'جديد' : 'New';
  String get progress => ar ? 'قيد التنفيذ' : 'In progress';
  String get closed => ar ? 'مغلق' : 'Closed';
  String get tabFresh => ar ? 'جديد' : 'New';
  String get tabActive => ar ? 'جاري' : 'Active';
  String get tabDone => ar ? 'مغلق' : 'Done';
  String get resetFilters => ar ? 'إعادة' : 'Reset';
  String get empty => ar ? 'لا توجد طلبات' : 'No requests';
  String get searchHint => ar ? 'ابحث برقم طلب الشراء' : 'Search by purchase number';
  String get create => ar ? 'طلب شراء جديد' : 'New purchase request';
  String get details => ar ? 'التفاصيل' : 'Details';
  String get notes => ar ? 'ملاحظات' : 'Notes';
  String get save => ar ? 'حفظ' : 'Save';
  String get saving => ar ? 'جاري الحفظ…' : 'Saving…';
  String get confirm => ar ? 'تأكيد' : 'Confirm';
  String get cancel => ar ? 'إلغاء' : 'Cancel';
  String get waitingServer => ar ? 'بانتظار تحديث السيرفر' : 'Waiting for the server update';
  String updatedOk(String po) => ar ? 'تم التحديث بنجاح $po' : 'Updated successfully $po';
  String updateFailed(String po) => ar
      ? 'آخر تحديث على طلب الشراء $po لم يتم. أعد المحاولة'
      : 'The last update on $po was not saved. Try again';
  String get attach => ar ? 'إرفاق صورة' : 'Attach a photo';
  String get camera => ar ? 'الكاميرا' : 'Camera';
  String get gallery => ar ? 'المعرض' : 'Gallery';
  String get site => ar ? 'الموقع' : 'Site';
  String get type => ar ? 'نوع الطلب' : 'Request type';
  String get poField => ar ? 'رقم طلب الشراء' : 'Purchase number';
  String get sinceProcurement => ar ? 'منذ دخوله المشتريات' : 'Since procurement';
  String get currentStage => ar ? 'المرحلة الحالية' : 'Current stage';
  String get waitingFor => ar ? 'بانتظار' : 'Waiting for';
  String get timeline => ar ? 'خط المراحل' : 'Stage timeline';
  String get log => ar ? 'سجل الحركة' : 'Activity log';
  String get ongoing => ar ? 'مستمرة' : 'In progress';
  String get changePassword => ar ? 'تغيير كلمة المرور' : 'Change password';
  String get currentPassword => ar ? 'كلمة المرور الحالية' : 'Current password';
  String get newPassword => ar ? 'كلمة المرور الجديدة' : 'New password';
  String get signOut => ar ? 'خروج' : 'Sign out';
  String get noNotifications => ar ? 'لا توجد إشعارات' : 'No notifications';
  String get loadMore => ar ? 'تحميل المزيد' : 'Load more';
  String get accountDeleted => ar ? 'تم حذف الحساب' : 'The account was deleted';
  String get noInternet => ar ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection';
  String get offlineRetry => ar
      ? 'لا يوجد إنترنت. رجاءً افحص الاتصال وحاول مرة أخرى'
      : 'No internet. Please check your connection and try again';
  String get pickSite => ar ? 'اختر الموقع' : 'Choose the site';
  String get pickType => ar ? 'اختر نوع الطلب' : 'Choose the request type';
  String get pickTrade => ar ? 'اختر التخصص' : 'Choose the trade';
  String get poFormat => ar
      ? 'رقم طلب الشراء يقبل حروفاً وأرقاماً فقط، بدون مسافات أو رموز'
      : 'The purchase number can contain letters and numbers only, with no spaces or symbols';
  String get notesRequired => ar ? 'أدخل الملاحظات قبل الحفظ' : 'Enter the notes before saving';
  String get userMissing => ar ? 'اسم المستخدم غير موجود' : 'Username was not found';
  String get wrongPassword => ar ? 'كلمة المرور غير صحيحة' : 'The password is incorrect';
  String get userRemoved => ar ? 'هذا المستخدم تم مسحه' : 'This user was removed';
  String get genericError =>
      ar ? 'تعذر إكمال العملية. أعد المحاولة' : 'The action could not be completed. Try again';
  String get addUser => ar ? 'إضافة مستخدم' : 'Add user';
  String get name => ar ? 'الاسم' : 'Name';
  String get delete => ar ? 'حذف' : 'Delete';
  String get reason => ar ? 'السبب' : 'Reason';
  String get alternative => ar ? 'توافر خامات بديلة' : 'Alternative materials available';
  String get alternativeHint =>
      ar ? 'اكتب الخامات والتفاصيل' : 'Enter the materials and details';
  String get advance => ar ? 'تحويل إلى المرحلة التالية' : 'Move to the next stage';
  String get approve => ar ? 'موافقة' : 'Approve';
  String get reject => ar ? 'رفض' : 'Reject';
  String get deleteNow => ar ? 'رفض وحذف طلب المواد' : 'Reject and delete the material request';
  String get recreateFromProcurement => ar
      ? 'يجب إبلاغ منشئ الطلب أن يعيد إنشاء الطلب من سيستم المشتريات. سيُغلق الطلب ويظهر في المغلق لدى المدير التنفيذي.'
      : 'The request creator must be told to recreate the request from the procurement system. The request will close and appear under Done for the executive director.';
  String get totalRequests => ar ? 'إجمالي الطلبات' : 'Total requests';
  String get deletedBefore => ar ? 'حُذف قبل المشتريات' : 'Deleted before procurement';
  String get closePo => ar ? 'تقفيل أمر الشراء والتوريد على النظام' : 'Close the PO and post it';
  String get contactCreator =>
      ar ? 'رجاء التواصل مع المسؤول الذي أنشأ الطلب' : 'Please contact the person who created the request';
  String get deletionPending =>
      ar ? 'بانتظار موافقة المدير التنفيذي على الإغلاق' : 'Waiting for the executive director to approve closure';
  String deletionAskedBy(String username) =>
      ar ? 'طلب حذف من $username — بانتظار المدير التنفيذي' : 'Deletion requested by $username — waiting for the executive director';
  String stageIndex(int index) => ar ? '$index/8' : '$index/8';
  String get flowMap => ar ? 'مسار الطلب' : 'Request path';
  String get flowchart => ar ? 'خريطة مراحل طلب الشراء' : 'Purchase request stages';
  String get eventAction => ar ? 'الإجراء' : 'Action';
  String get allSites => ar ? 'كل المواقع' : 'All sites';
  String get fifth => ar ? 'التجمع الخامس' : 'Fifth Settlement';
  String get kourba => ar ? 'الكوربة هايتس' : 'Kourba Heights';
  String get retry => ar ? 'إعادة المحاولة' : 'Try again';
  String get required => ar ? 'هذا الحقل مطلوب' : 'This field is required';

  String stage(String code) {
    const arMap = {
      'mr': 'طلب مواد MR',
      'pr': 'طلب شراء PR',
      'rfq': 'عروض الأسعار RFQ / ITB',
      'po': 'أمر الشراء PO',
      'do': 'إشعار التسليم DO / ASN',
      'grn': 'استلام المخزون GRN',
      'tir': 'الفحص الفني TIR',
      'mrv': 'مطابقة الفاتورة MRV / IR',
      'closed': 'مغلق',
    };
    const enMap = {
      'mr': 'Material request MR',
      'pr': 'Procurement request PR',
      'rfq': 'RFQ / ITB',
      'po': 'Purchase order PO',
      'do': 'Delivery notice DO / ASN',
      'grn': 'Goods receipt GRN',
      'tir': 'Technical inspection TIR',
      'mrv': 'Invoice match MRV / IR',
      'closed': 'Closed',
    };
    return (ar ? arMap : enMap)[code] ?? code;
  }

  String typeLabel(String code) {
    switch (code) {
      case 'execution':
        return ar ? 'تنفيذ' : 'Execution';
      case 'regular':
        return ar ? 'اعتيادي' : 'Regular';
      default:
        return ar ? 'صيانة وتشغيل' : 'Maintenance and operations';
    }
  }

  String waiting(String code, {required bool kourba, String department = ''}) {
    switch (code) {
      case 'mr':
        if (department == 'landscape') return ar ? 'المدير التنفيذي' : 'the executive director';
        return ar ? 'مدير الإدارة' : 'the department manager';
      case 'pr':
      case 'rfq':
      case 'po':
        return ar ? 'قسم المشتريات' : 'procurement';
      case 'do':
      case 'grn':
        return ar ? 'المشتريات أو مسؤول المخازن' : 'procurement or the warehouse responsible';
      case 'tir':
        return ar ? 'منشئ الطلب' : 'the person who created the request';
      case 'mrv':
        return kourba
            ? (ar ? 'المشتريات أو المخازن' : 'procurement or the warehouse')
            : (ar ? 'المشتريات أو مدير المخازن' : 'procurement or the warehouse manager');
      default:
        return ar ? 'لا أحد' : 'no one';
    }
  }

  String actionLabel(String action, String stageCode) {
    switch (action) {
      case 'create':
        return ar ? 'إنشاء الطلب' : 'Created the request';
      case 'advance':
        return '${ar ? 'تحويل إلى' : 'Move to'} ${stage(stageCode)}';
      case 'approveMr':
        return ar ? 'موافقة وتحويل إلى طلب شراء PR' : 'Approve and move to PR';
      case 'rejectMr':
        return ar ? 'رفض طلب المواد' : 'Reject the material request';
      case 'deleteNow':
        return deleteNow;
      case 'requestDelete':
        return ar ? 'طلب حذف' : 'Request deletion';
      case 'approveDelete':
        return ar ? 'الموافقة على الحذف' : 'Approve deletion';
      case 'rejectDelete':
        return ar ? 'رفض الحذف' : 'Reject deletion';
      case 'alternative':
        return alternative;
      case 'approveTir':
        return ar ? 'اعتماد الفحص الفني' : 'Accept technical inspection';
      case 'rejectTir':
        return ar ? 'رفض الفحص NCR' : 'Reject inspection NCR';
      case 'closePo':
        return closePo;
      case 'directDelete':
        return ar ? 'إغلاق الطلب مع تسجيل السبب' : 'Close the request and record the reason';
      default:
        return action;
    }
  }

  String job(String code) {
    const arMap = {
      'mallMaintenanceEngineer': 'مهندس صيانة في مول',
      'mallOpsLead': 'مدير تشغيل مول',
      'mallsOpsManager': 'مدير تشغيل مولات التجمع',
      'mepExecutionEngineer': 'مهندس تنفيذ كهرباء أو ميكانيكا',
      'mepManager': 'مدير الصيانة الكهروميكانيكية',
      'lowCurrentEngineer': 'مهندس تيار خفيف',
      'lowCurrentManager': 'مدير التيار الخفيف',
      'civilEngineer': 'مهندس مدني',
      'civilManager': 'مدير التنفيذ المدني',
      'procurement': 'المشتريات',
      'fifthStorekeeper': 'مسؤول مخازن التجمع',
      'fifthStoreManager': 'مدير مخازن التجمع',
      'kourbaStorekeeper': 'مسؤول مخازن الكوربة',
      'kourbaStoreManager': 'مدير مخازن الكوربة',
      'itEngineer': 'مهندس تكنولوجيا المعلومات',
      'itManager': 'مدير قسم تكنولوجيا المعلومات',
      'landscape': 'مسؤول اللاند سكيب',
      'kourbaDirector': 'مدير قطاع الكوربة',
    };
    const enMap = {
      'mallMaintenanceEngineer': 'Mall maintenance engineer',
      'mallOpsLead': 'Mall operations manager',
      'mallsOpsManager': 'Fifth Settlement malls operations manager',
      'mepExecutionEngineer': 'Electrical or mechanical execution engineer',
      'mepManager': 'MEP manager',
      'lowCurrentEngineer': 'Low-current engineer',
      'lowCurrentManager': 'Low-current manager',
      'civilEngineer': 'Civil engineer',
      'civilManager': 'Civil execution manager',
      'procurement': 'Procurement',
      'fifthStorekeeper': 'Fifth warehouse responsible',
      'fifthStoreManager': 'Fifth warehouse manager',
      'kourbaStorekeeper': 'Kourba warehouse responsible',
      'kourbaStoreManager': 'Kourba warehouse manager',
      'itEngineer': 'IT engineer',
      'itManager': 'IT manager',
      'landscape': 'Landscape responsible',
      'kourbaDirector': 'Kourba sector director',
    };
    return (ar ? arMap : enMap)[code] ?? code;
  }

  String get deleteUserTitle => ar ? 'حذف المستخدم' : 'Delete user';
  String deleteUserBody(String name) => ar ? 'هل تريد حذف $name؟' : 'Delete $name?';
  String get area => ar ? 'النطاق' : 'Area';
  String get fifthArea => ar ? 'التجمع الخامس' : 'Fifth Settlement';
  String get trade => ar ? 'التخصص' : 'Trade';
  String tradeLabel(String code) {
    switch (code) {
      case 'electrical':
        return electrical;
      case 'mechanical':
        return mechanical;
      case 'lowCurrent':
        return ar ? 'تيار خفيف' : 'Low current';
      case 'civil':
        return ar ? 'مدني' : 'Civil';
      case 'landscape':
        return ar ? 'لاند سكيب' : 'Landscape';
      case 'it':
        return ar ? 'تكنولوجيا المعلومات' : 'IT';
      case 'operations':
        return ar ? 'تشغيل المولات' : 'Mall operations';
      default:
        return code;
    }
  }
  String get electrical => ar ? 'كهرباء' : 'Electrical';
  String get mechanical => ar ? 'ميكانيكا' : 'Mechanical';
  String get all => ar ? 'الكل' : 'All';
  String get jobField => ar ? 'المسمى' : 'Job';
  String get editUser => ar ? 'تعديل المستخدم' : 'Edit user';
  String get disableUser => ar ? 'تعطيل' : 'Disable';
  String get enableUser => ar ? 'تفعيل' : 'Enable';
  String get activeUser => ar ? 'نشط' : 'Active';
  String get disabledUser => ar ? 'معطّل' : 'Disabled';
  String get removedUser => ar ? 'محذوف' : 'Removed';
  String get optionalPassword => ar ? 'كلمة مرور جديدة، اتركها فارغة للإبقاء على الحالية' : 'New password, leave empty to keep the current one';
  String disableUserBody(String name) => ar ? 'هل تريد تعطيل $name؟ لن يستطيع الدخول حتى تفعّله.' : 'Disable $name? They cannot sign in until you enable them.';
  String enableUserBody(String name) => ar ? 'هل تريد تفعيل $name؟' : 'Enable $name?';
  String get userSaved => ar ? 'تم حفظ المستخدم' : 'User saved';
  String get usernameTaken => ar ? 'اسم المستخدم مستخدم من قبل' : 'That username is already used';
  String get usernameFormat => ar
      ? 'لا تستخدم مسافة أو الرمز /'
      : 'Do not use spaces or /';
  String get createUserFailed => ar ? 'تعذر إنشاء المستخدم. أعد المحاولة' : 'The user could not be created. Try again';
  String get weakPassword => ar ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : 'The password must be at least 6 characters';
  String get accountDisabled => ar ? 'هذا الحساب معطّل' : 'This account is disabled';
  String get allSitesLabel => ar ? 'كل المواقع' : 'All sites';
  String get noUsers => ar ? 'لا يوجد مستخدمون' : 'No users';
  String get executiveTitle => ar ? 'المدير التنفيذي' : 'Executive director';
  String get restoreDirector => ar ? 'استعادة حساب المدير' : 'Restore director account';
  String get ownerKey => ar ? 'مفتاح المالك' : 'Owner key';
  String get restoreDirectorHint => ar
      ? 'للمالك فقط. أدخل مفتاح المشروع ثم كلمة مرور جديدة للمدير التنفيذي.'
      : 'Owner only. Enter the project key, then a new password for the executive director.';
  String get restoreDirectorOk => ar ? 'تم تعيين كلمة المرور. يمكن للمدير الدخول بها الآن.' : 'The password was set. The director can sign in with it now.';
  String get badOwnerKey => ar ? 'مفتاح المالك غير صحيح' : 'The owner key is incorrect';
  String get needAction => ar ? 'بانتظارك' : 'NEED ACTION';
  String get period => ar ? 'مدة بقاء الطلب في المرحلة' : 'Time the request stayed in this stage';
  String get actionAt => ar ? 'وقت الإجراء' : 'Action time';
  String get imageBad => ar ? 'تعذر قراءة الصورة. اختر صورة JPG أو PNG' : 'The image could not be read. Choose a JPG or PNG photo';
  String get poExists => ar ? 'رقم أمر الشراء مستخدم من قبل' : 'That purchase number is already used';
  String confirmPo(String po) =>
      ar ? 'رقم طلب الشراء الذي سيُحفظ هو $po. تأكيد؟' : 'The purchase number that will be saved is $po. Confirm?';
  String get allStages => ar ? 'كل المراحل' : 'All stages';
  String get resetPassword => ar ? 'إعادة تعيين كلمة المرور' : 'Reset password';
  String resetPasswordBody(String name) => ar
      ? 'سيتم تعيين كلمة مرور جديدة لـ $name، وسيُطلب منه تغييرها عند الدخول.'
      : 'A new password will be set for $name, and they must change it at the next sign-in.';
  String get mustChangePassword => ar ? 'يجب تعيين كلمة مرور جديدة للمتابعة' : 'Set a new password to continue';
  String get passwordChanged => ar ? 'تم تغيير كلمة المرور' : 'Password changed';
  String get showPassword => ar ? 'إظهار كلمة المرور' : 'Show password';
  String get hidePassword => ar ? 'إخفاء كلمة المرور' : 'Hide password';
  String get lessThanHour => ar ? 'أقل من ساعة' : 'Less than an hour';
  String monthsUnit(int n) => ar ? '$n شهر' : '$n mo';
  String daysUnit(int n) => ar ? '$n يوم' : '$n d';
  String hoursUnit(int n) => ar ? '$n ساعة' : '$n h';
  String departmentLabel(String code) {
    switch (code) {
      case 'lowCurrent':
        return ar ? 'تيار خفيف' : 'Low current';
      case 'civilFifth':
      case 'civilKourba':
        return ar ? 'مدني' : 'Civil';
      case 'mallOps':
        return ar ? 'تشغيل المولات' : 'Mall operations';
      case 'landscape':
        return ar ? 'لاند سكيب' : 'Landscape';
      case 'it':
        return ar ? 'تكنولوجيا المعلومات' : 'IT';
      case 'mep':
        return 'MEP';
      case 'procurement':
        return ar ? 'المشتريات' : 'Procurement';
      case 'warehouseFifth':
      case 'warehouseKourba':
        return ar ? 'المخازن' : 'Warehouse';
      case 'executiveOffice':
        return executiveTitle;
      case 'kourbaOffice':
        return job('kourbaDirector');
      default:
        return code;
    }
  }
}
